<script>
  import Scanner   from './routes/Scanner.svelte'
  import Gallery   from './routes/Gallery.svelte'
  import Duplicates from './routes/Duplicates.svelte'
  import Organizer from './routes/Organizer.svelte'

  const tabs = [
    { id: 'scanner',    label: 'Scanner',    icon: '📁' },
    { id: 'gallery',    label: 'Gallery',    icon: '🖼' },
    { id: 'duplicates', label: 'Duplicates', icon: '🔁' },
    { id: 'organize',   label: 'Organize',   icon: '📋' },
  ]

  let active = 'scanner'
</script>

<div class="shell">
  <nav class="sidebar">
    <div class="logo">PhotoSorter</div>
    {#each tabs as t}
      <button
        class="tab-btn"
        class:active={active === t.id}
        on:click={() => active = t.id}
      >
        <span class="icon">{t.icon}</span>
        <span class="label">{t.label}</span>
      </button>
    {/each}
  </nav>

  <main class="content">
    {#if active === 'scanner'}
      <Scanner />
    {:else if active === 'gallery'}
      <Gallery />
    {:else if active === 'duplicates'}
      <Duplicates />
    {:else if active === 'organize'}
      <Organizer />
    {/if}
  </main>
</div>

<style>
  :global(*, *::before, *::after) { box-sizing: border-box; }
  :global(body) {
    margin: 0;
    font-family: system-ui, -apple-system, sans-serif;
    background: #111;
    color: #ddd;
  }

  .shell {
    display: flex;
    height: 100vh;
    overflow: hidden;
  }

  .sidebar {
    width: 180px;
    min-width: 180px;
    background: #0d0d0d;
    border-right: 1px solid #1e1e1e;
    display: flex;
    flex-direction: column;
    padding: 16px 0;
    gap: 2px;
  }

  .logo {
    padding: 0 18px 18px;
    font-size: 0.95rem;
    font-weight: 700;
    color: #4a9eff;
    letter-spacing: 0.5px;
    border-bottom: 1px solid #1e1e1e;
    margin-bottom: 10px;
  }

  .tab-btn {
    display: flex;
    align-items: center;
    gap: 10px;
    background: none;
    border: none;
    color: #777;
    width: 100%;
    text-align: left;
    padding: 10px 18px;
    cursor: pointer;
    font-size: 0.88rem;
    border-radius: 0;
    transition: background 0.1s, color 0.1s;
  }
  .tab-btn:hover  { background: #1a1a1a; color: #ccc; }
  .tab-btn.active { background: #1a2a40; color: #4a9eff; font-weight: 600; }

  .icon  { font-size: 1rem; width: 20px; text-align: center; }
  .label { flex: 1; }

  .content {
    flex: 1;
    overflow-y: auto;
    background: #111;
  }
</style>
