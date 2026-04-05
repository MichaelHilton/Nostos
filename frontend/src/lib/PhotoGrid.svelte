<script>
  import PhotoCard from './PhotoCard.svelte'

  export let photos = []
  export let loading = false
  export let selectedIds = new Set()
  export let onSelect = () => {}
  export let onLoadMore = null
  export let total = 0
</script>

{#if loading && photos.length === 0}
  <div class="state">Loading…</div>
{:else if photos.length === 0}
  <div class="state">No photos found.</div>
{:else}
  <div class="grid">
    {#each photos as photo (photo.id)}
      <PhotoCard
        {photo}
        selected={selectedIds.has(photo.id)}
        onSelect={() => onSelect(photo)}
      />
    {/each}
  </div>

  {#if onLoadMore && photos.length < total}
    <div class="load-more">
      <button on:click={onLoadMore} disabled={loading}>
        {loading ? 'Loading…' : `Load more (${photos.length} / ${total})`}
      </button>
    </div>
  {/if}
{/if}

<style>
  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
    gap: 8px;
    padding: 12px;
  }

  .state {
    padding: 40px;
    text-align: center;
    color: #555;
  }

  .load-more {
    display: flex;
    justify-content: center;
    padding: 16px;
  }
  .load-more button {
    background: #2a2a2a;
    border: 1px solid #444;
    color: #ccc;
    padding: 8px 24px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.85rem;
  }
  .load-more button:hover:not(:disabled) { background: #333; }
  .load-more button:disabled { opacity: 0.5; cursor: default; }
</style>
