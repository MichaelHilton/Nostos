<script>
  import { listDuplicates, resolveDuplicate, getThumbnailDataURL } from '../lib/wailsbridge.js'

  let groups = []
  let loading = true
  let error = ''
  let saving = new Set()

  async function load() {
    loading = true
    try {
      groups = (await listDuplicates()) ?? []
    } catch (e) {
      error = e.message
    } finally {
      loading = false
    }
  }
  load()

  async function keepPhoto(group, photo) {
    saving.add(group.id)
    saving = saving
    try {
      await resolveDuplicate(group.id, photo.id)
      groups = groups.map(g => {
        if (g.id !== group.id) return g
        return {
          ...g,
          kept_photo_id: photo.id,
          photos: g.photos.map(p => ({ ...p, is_kept: p.id === photo.id }))
        }
      })
    } catch (e) {
      error = e.message
    } finally {
      saving.delete(group.id)
      saving = saving
    }
  }

  function formatSize(bytes) {
    if (!bytes) return '—'
    if (bytes > 1024 * 1024) return (bytes / 1024 / 1024).toFixed(1) + ' MB'
    return (bytes / 1024).toFixed(0) + ' KB'
  }

  function formatDate(d) {
    if (!d) return '—'
    return new Date(d).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })
  }

  function basename(path) {
    return path?.split('/')?.pop() ?? path
  }

  function thumbFor(photo) {
    if (!photo.thumbnail_path) return Promise.resolve(null)
    return getThumbnailDataURL(photo.id).catch(() => null)
  }
</script>

<div class="page">
  <div class="header">
    <h2>Duplicate Groups</h2>
    <p class="hint">
      Review groups of identical or near-identical photos. Choose which copy to keep.
      No files are ever deleted — only the <strong>kept</strong> photo will be copied during organize.
    </p>
  </div>

  {#if error}
    <p class="err">{error}</p>
  {/if}

  {#if loading}
    <div class="state">Loading…</div>
  {:else if groups.length === 0}
    <div class="state">🎉 No duplicates found. Run a scan first.</div>
  {:else}
    <p class="count">{groups.length} group{groups.length !== 1 ? 's' : ''}</p>

    {#each groups as group (group.id)}
      <div class="group" class:saving={saving.has(group.id)}>
        <div class="group-header">
          <span class="group-id">Group #{group.id}</span>
          <span class="reason">{group.reason === 'hash_match' ? '🔑 Exact duplicate' : '📅 Same EXIF timestamp'}</span>
          {#if saving.has(group.id)}
            <span class="spinner-sm"></span>
          {/if}
        </div>

        <div class="photos">
          {#each group.photos as photo (photo.id)}
            <div class="photo-row" class:kept={photo.is_kept}>
              <div class="thumb">
                {#await thumbFor(photo) then src}
                  {#if src}
                    <img {src} alt="" />
                  {:else}
                    <div class="no-thumb">{basename(photo.path).split('.').pop()?.toUpperCase()}</div>
                  {/if}
                {/await}
              </div>

              <div class="info">
                <p class="name" title={photo.path}>{basename(photo.path)}</p>
                <p class="sub">{photo.path}</p>
                <p class="sub">{formatDate(photo.taken_at)} · {formatSize(photo.file_size)}</p>
                {#if photo.camera_model}
                  <p class="sub cam">{photo.camera_model}</p>
                {/if}
              </div>

              <div class="actions">
                {#if photo.is_kept}
                  <span class="kept-badge">✓ Kept</span>
                {:else}
                  <button
                    class="keep-btn"
                    on:click={() => keepPhoto(group, photo)}
                    disabled={saving.has(group.id)}
                  >
                    Keep this
                  </button>
                {/if}
              </div>
            </div>
          {/each}
        </div>
      </div>
    {/each}
  {/if}
</div>

<style>
  .page { padding: 24px; max-width: 900px; }
  .header h2 { margin: 0 0 6px; }
  .hint { color: #888; font-size: 0.88rem; margin: 0 0 20px; }
  .hint strong { color: #ccc; }
  .err   { color: #ff5555; font-size: 0.85rem; }
  .state { padding: 40px; text-align: center; color: #555; }
  .count { font-size: 0.82rem; color: #666; margin-bottom: 16px; }

  .group {
    background: #141414;
    border: 1px solid #2a2a2a;
    border-radius: 8px;
    margin-bottom: 16px;
    overflow: hidden;
    transition: opacity 0.2s;
  }
  .group.saving { opacity: 0.7; }

  .group-header {
    padding: 10px 16px;
    background: #1a1a1a;
    border-bottom: 1px solid #2a2a2a;
    display: flex;
    align-items: center;
    gap: 12px;
    font-size: 0.8rem;
  }
  .group-id { color: #666; font-family: monospace; }
  .reason   { color: #aaa; }

  .spinner-sm {
    width: 14px; height: 14px;
    border: 2px solid #333; border-top-color: #4a9eff;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
    margin-left: auto;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  .photos { display: flex; flex-direction: column; }

  .photo-row {
    display: flex;
    align-items: center;
    gap: 14px;
    padding: 10px 16px;
    border-bottom: 1px solid #1e1e1e;
    transition: background 0.1s;
  }
  .photo-row:last-child { border-bottom: none; }
  .photo-row.kept { background: #1a2a1a; }

  .thumb {
    width: 60px; height: 60px;
    flex-shrink: 0;
    background: #111;
    border-radius: 4px;
    overflow: hidden;
    display: flex; align-items: center; justify-content: center;
  }
  .thumb img { width: 100%; height: 100%; object-fit: cover; }
  .no-thumb  { color: #444; font-size: 0.65rem; font-weight: 700; }

  .info { flex: 1; min-width: 0; }
  .name {
    margin: 0 0 2px;
    font-size: 0.85rem;
    color: #ccc;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .sub {
    margin: 0;
    font-size: 0.7rem;
    color: #666;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    font-family: monospace;
  }
  .cam { font-family: sans-serif; }

  .actions { flex-shrink: 0; }
  .kept-badge { font-size: 0.75rem; color: #44cc88; font-weight: 600; }
  .keep-btn {
    background: #1a1a2a;
    border: 1px solid #4a9eff44;
    color: #4a9eff;
    padding: 5px 12px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.78rem;
  }
  .keep-btn:hover:not(:disabled) { background: #4a9eff22; }
  .keep-btn:disabled { opacity: 0.4; cursor: default; }
</style>
