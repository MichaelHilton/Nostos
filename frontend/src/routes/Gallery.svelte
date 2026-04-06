<script>
  import { listPhotos, getPhoto, getThumbnailDataURL } from '../lib/wailsbridge.js'
  import PhotoGrid from '../lib/PhotoGrid.svelte'

  const PAGE = 100

  let photos = []
  let total = 0
  let offset = 0
  let loading = false
  let selectedIds = new Set()
  let detail = null
  let detailThumb = null

  // Filters
  let filterStatus = ''
  let filterCamera = ''
  let filterFrom = ''
  let filterTo = ''
  let filterDups = ''

  async function load(reset = false) {
    if (reset) { photos = []; offset = 0 }
    loading = true
    try {
      const params = { limit: PAGE, offset }
      if (filterStatus)      params.status        = filterStatus
      if (filterCamera)      params.cameraModel   = filterCamera
      if (filterFrom)        params.dateFrom      = filterFrom
      if (filterTo)          params.dateTo        = filterTo
      if (filterDups !== '') params.hasDuplicates = filterDups === 'true'
      const res = await listPhotos(params)
      photos = reset ? (res.photos ?? []) : [...photos, ...(res.photos ?? [])]
      total  = res.total ?? 0
      offset = photos.length
    } finally {
      loading = false
    }
  }

  load(true)

  function toggleSelect(photo) {
    if (selectedIds.has(photo.id)) selectedIds.delete(photo.id)
    else selectedIds.add(photo.id)
    selectedIds = selectedIds
  }

  async function openDetail(photo) {
    detail = await getPhoto(photo.id)
    detailThumb = null
    if (detail?.thumbnail_path) {
      detailThumb = await getThumbnailDataURL(detail.id).catch(() => null)
    }
  }

  function formatDate(d) {
    if (!d) return '—'
    return new Date(d).toLocaleString()
  }
</script>

<div class="layout">
  <!-- Filter sidebar -->
  <aside class="filters">
    <h3>Filter</h3>

    <label>Status
      <select bind:value={filterStatus} on:change={() => load(true)}>
        <option value="">All</option>
        <option value="new">New</option>
        <option value="copied">Copied</option>
        <option value="skipped_duplicate">Skipped (dup)</option>
        <option value="skipped_exists">Skipped (exists)</option>
      </select>
    </label>

    <label>Camera
      <input type="text" bind:value={filterCamera} placeholder="e.g. iPhone 15" on:change={() => load(true)} />
    </label>

    <label>Date from
      <input type="date" bind:value={filterFrom} on:change={() => load(true)} />
    </label>

    <label>Date to
      <input type="date" bind:value={filterTo} on:change={() => load(true)} />
    </label>

    <label>Duplicates
      <select bind:value={filterDups} on:change={() => load(true)}>
        <option value="">All</option>
        <option value="true">Has duplicate</option>
        <option value="false">No duplicate</option>
      </select>
    </label>

    <button class="reset" on:click={() => {
      filterStatus = ''; filterCamera = ''; filterFrom = '';
      filterTo = ''; filterDups = '';
      load(true)
    }}>Clear filters</button>

    <p class="count">{total} photo{total !== 1 ? 's' : ''}</p>
    {#if selectedIds.size > 0}
      <p class="sel">{selectedIds.size} selected</p>
    {/if}
  </aside>

  <!-- Grid -->
  <main class="main">
    <PhotoGrid
      {photos}
      {loading}
      {total}
      {selectedIds}
      onSelect={(p) => { toggleSelect(p); openDetail(p) }}
      onLoadMore={() => load(false)}
    />
  </main>

  <!-- Detail panel -->
  {#if detail}
    <aside class="detail">
      <button class="close" on:click={() => { detail = null; detailThumb = null }}>✕</button>
      {#if detailThumb}
        <img src={detailThumb} alt="preview" class="preview" />
      {/if}
      <h4>Details</h4>
      <dl>
        <dt>Path</dt>      <dd class="mono">{detail.path}</dd>
        <dt>Status</dt>    <dd><span class="pill {detail.status}">{detail.status}</span></dd>
        <dt>Taken</dt>     <dd>{formatDate(detail.taken_at)}</dd>
        <dt>Camera</dt>    <dd>{detail.camera_make} {detail.camera_model || '—'}</dd>
        <dt>Size</dt>      <dd>{(detail.file_size / 1024 / 1024).toFixed(2)} MB</dd>
        <dt>Dimensions</dt><dd>{detail.width > 0 ? `${detail.width} × ${detail.height}` : '—'}</dd>
        {#if detail.gps_lat}
          <dt>GPS</dt>     <dd>{detail.gps_lat?.toFixed(5)}, {detail.gps_lon?.toFixed(5)}</dd>
        {/if}
        <dt>Hash</dt>      <dd class="mono hash">{detail.hash?.slice(0, 16)}…</dd>
      </dl>
    </aside>
  {/if}
</div>

<style>
  .layout { display: flex; height: 100%; overflow: hidden; }

  .filters {
    width: 200px;
    flex-shrink: 0;
    background: #111;
    border-right: 1px solid #222;
    padding: 16px;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  h3 { margin: 0; font-size: 0.85rem; text-transform: uppercase; color: #555; letter-spacing: 0.08em; }
  label { display: flex; flex-direction: column; gap: 3px; font-size: 0.78rem; color: #888; }
  label input, label select {
    background: #1a1a1a; border: 1px solid #333; color: #ddd;
    padding: 5px 7px; border-radius: 3px; font-size: 0.8rem;
  }
  label input:focus, label select:focus { outline: none; border-color: #4a9eff; }
  .reset {
    background: none; border: 1px solid #333; color: #888;
    padding: 5px; border-radius: 3px; cursor: pointer; font-size: 0.78rem;
  }
  .reset:hover { border-color: #555; color: #ccc; }
  .count { margin: 0; font-size: 0.78rem; color: #555; }
  .sel   { margin: 0; font-size: 0.78rem; color: #4a9eff; }

  .main { flex: 1; overflow-y: auto; }

  .detail {
    width: 240px;
    flex-shrink: 0;
    background: #111;
    border-left: 1px solid #222;
    padding: 16px;
    overflow-y: auto;
    position: relative;
  }
  .close {
    position: absolute; top: 8px; right: 10px;
    background: none; border: none; color: #666; cursor: pointer; font-size: 1rem;
  }
  .preview { width: 100%; aspect-ratio: 1; object-fit: cover; border-radius: 4px; margin-bottom: 12px; }
  h4 { margin: 0 0 10px; font-size: 0.85rem; color: #888; }
  dl { margin: 0; display: grid; grid-template-columns: auto 1fr; gap: 4px 10px; font-size: 0.75rem; }
  dt { color: #666; }
  dd { color: #ccc; margin: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .mono { font-family: monospace; font-size: 0.7rem; }
  .hash { color: #888; }
  .pill {
    display: inline-block; padding: 1px 7px; border-radius: 10px;
    font-size: 0.68rem; font-weight: 600;
  }
  .pill.new               { background: #333; color: #999; }
  .pill.copied            { background: #1acc8833; color: #44cc88; }
  .pill.skipped_duplicate { background: #ff994433; color: #ff9944; }
  .pill.skipped_exists    { background: #44aaff33; color: #44aaff; }
</style>
