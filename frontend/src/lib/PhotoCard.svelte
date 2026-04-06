<script>
  import { getThumbnailDataURL } from './wailsbridge.js'

  export let photo
  export let selected = false
  export let onSelect = () => {}

  function formatDate(d) {
    if (!d) return 'Unknown date'
    return new Date(d).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })
  }

  // Lazy-load the thumbnail as a base64 data URL only when this card renders.
  const thumbPromise = photo.thumbnail_path
    ? getThumbnailDataURL(photo.id).catch(() => null)
    : Promise.resolve(null)
</script>

<button
  class="card"
  class:selected
  class:duplicate={photo.duplicate_group_id}
  on:click={() => onSelect(photo)}
  title={photo.path}
>
  <div class="thumb-wrap">
    {#await thumbPromise then src}
      {#if src}
        <img {src} alt={photo.path} loading="lazy" />
      {:else}
        <div class="no-thumb">
          <span>{photo.path?.split('.').pop()?.toUpperCase() ?? '?'}</span>
        </div>
      {/if}
    {/await}

    {#if photo.duplicate_group_id}
      <span class="badge dup">DUP</span>
    {/if}
    {#if photo.status === 'copied'}
      <span class="badge copied">✓</span>
    {/if}
    {#if selected}
      <div class="check">✓</div>
    {/if}
  </div>

  <div class="meta">
    <p class="date">{formatDate(photo.taken_at)}</p>
    {#if photo.camera_model}
      <p class="camera">{photo.camera_model}</p>
    {/if}
  </div>
</button>

<style>
  .card {
    background: #1a1a1a;
    border: 2px solid transparent;
    border-radius: 6px;
    padding: 0;
    cursor: pointer;
    transition: border-color 0.15s, transform 0.1s;
    text-align: left;
    overflow: hidden;
    width: 100%;
  }
  .card:hover { border-color: #555; transform: scale(1.02); }
  .card.selected { border-color: #4a9eff; }
  .card.duplicate { border-color: #ff9944; }
  .card.selected.duplicate { border-color: #4a9eff; }

  .thumb-wrap {
    position: relative;
    width: 100%;
    aspect-ratio: 1;
    background: #111;
    overflow: hidden;
    display: flex; align-items: center; justify-content: center;
  }
  .thumb-wrap img {
    width: 100%; height: 100%;
    object-fit: cover;
    display: block;
  }
  .no-thumb {
    color: #555;
    font-size: 0.75rem;
    font-weight: 700;
    letter-spacing: 0.05em;
  }

  .badge {
    position: absolute;
    top: 4px;
    right: 4px;
    padding: 1px 5px;
    border-radius: 3px;
    font-size: 0.6rem;
    font-weight: 700;
    line-height: 1.4;
  }
  .badge.dup    { background: #ff9944; color: #000; top: 4px; right: 4px; }
  .badge.copied { background: #44cc88; color: #000; top: 4px; left: 4px; right: auto; }

  .check {
    position: absolute;
    inset: 0;
    background: rgba(74, 158, 255, 0.25);
    display: flex; align-items: center; justify-content: center;
    font-size: 2rem;
    color: #4a9eff;
  }

  .meta { padding: 5px 7px 6px; }
  .meta p { margin: 0; }
  .date   { font-size: 0.7rem; color: #aaa; }
  .camera { font-size: 0.65rem; color: #666; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
</style>
