<script>
  import { startScan, listScans, pickDirectory, onEvent, offEvent } from '../lib/wailsbridge.js'

  let rootPath = ''
  let scanning = false
  let currentRun = null
  let recentScans = []
  let error = ''

  async function loadScans() {
    try {
      recentScans = (await listScans()) ?? []
    } catch {}
  }

  async function chooseDirectory() {
    try {
      const path = await pickDirectory()
      if (path) rootPath = path
    } catch (e) {
      error = e.message
    }
  }

  loadScans()

  async function submitScan() {
    if (!rootPath.trim()) return
    error = ''
    scanning = true

    try {
      const res = await startScan(rootPath.trim())
      currentRun = { id: res.scan_run_id, status: 'running' }

      onEvent('scan:progress', (run) => {
        currentRun = run
      })
      onEvent('scan:done', (run) => {
        currentRun = run
        scanning = false
        offEvent('scan:progress', 'scan:done')
        loadScans()
      })
    } catch (e) {
      error = e.message
      scanning = false
    }
  }

  function formatDate(d) {
    if (!d) return '—'
    return new Date(d).toLocaleString()
  }
</script>

<div class="page">
  <h2>Scan a Directory</h2>
  <p class="hint">
    Point the scanner at a folder on any connected drive. All sub-folders are
    scanned recursively. No files are moved or deleted.
  </p>

  <form class="scan-form" on:submit|preventDefault={submitScan}>
    <button
      type="button"
      class="picker-button"
      on:click={chooseDirectory}
      disabled={scanning}
    >
      {rootPath ? 'Change directory' : 'Choose directory'}
    </button>
    <input
      type="text"
      readonly
      value={rootPath}
      placeholder="No folder selected"
      disabled={scanning}
      class:error={!!error}
    />
    <button type="submit" disabled={scanning || !rootPath.trim()}>
      {scanning ? 'Scanning…' : 'Start Scan'}
    </button>
  </form>

  {#if error}
    <p class="err">{error}</p>
  {/if}

  {#if currentRun}
    <div
      class="run-status"
      class:running={currentRun.status === 'running'}
      class:done={currentRun.status === 'completed'}
    >
      <strong>Run #{currentRun.id}</strong>
      <span class="status-pill {currentRun.status}">{currentRun.status}</span>
      <div class="stats">
        <span>📷 {currentRun.photos_found ?? 0} photos found</span>
        <span>🔁 {currentRun.duplicates_found ?? 0} duplicates</span>
      </div>
      {#if currentRun.status === 'running'}
        <div class="spinner"></div>
      {/if}
    </div>
  {/if}

  {#if recentScans.length > 0}
    <section class="history">
      <h3>Recent Scans</h3>
      <table>
        <thead>
          <tr><th>ID</th><th>Path</th><th>Started</th><th>Photos</th><th>Dups</th><th>Status</th></tr>
        </thead>
        <tbody>
          {#each recentScans as run}
            <tr>
              <td>#{run.id}</td>
              <td class="path">{run.root_path}</td>
              <td>{formatDate(run.started_at)}</td>
              <td>{run.photos_found}</td>
              <td>{run.duplicates_found}</td>
              <td><span class="status-pill {run.status}">{run.status}</span></td>
            </tr>
          {/each}
        </tbody>
      </table>
    </section>
  {/if}
</div>

<style>
  .page {
    padding: 24px;
    max-width: 900px;
  }
  h2 {
    margin: 0 0 6px;
    font-size: 1.4rem;
  }
  .hint {
    color: #888;
    margin: 0 0 20px;
    font-size: 0.9rem;
  }

  .scan-form {
    display: flex;
    gap: 8px;
  }
  .scan-form input {
    flex: 1;
    background: #1a1a1a;
    border: 1px solid #444;
    color: #eee;
    padding: 10px 12px;
    border-radius: 4px;
    font-size: 0.95rem;
  }
  .scan-form input.error {
    border-color: #ff5555;
  }
  .scan-form input:focus {
    outline: none;
    border-color: #4a9eff;
  }
  .scan-form button {
    background: #4a9eff;
    border: none;
    color: #000;
    padding: 10px 20px;
    border-radius: 4px;
    font-weight: 600;
    cursor: pointer;
    white-space: nowrap;
  }
  .scan-form button:disabled {
    opacity: 0.5;
    cursor: default;
  }

  .err {
    color: #ff5555;
    font-size: 0.85rem;
    margin-top: 8px;
  }

  .run-status {
    margin-top: 20px;
    background: #1a1a1a;
    border: 1px solid #333;
    border-radius: 6px;
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .run-status.running { border-color: #4a9eff; }
  .run-status.done    { border-color: #44cc88; }

  .stats {
    display: flex;
    gap: 20px;
    color: #aaa;
    font-size: 0.85rem;
  }

  .status-pill {
    display: inline-block;
    padding: 2px 8px;
    border-radius: 12px;
    font-size: 0.7rem;
    font-weight: 700;
    text-transform: uppercase;
    margin-left: 8px;
  }
  .status-pill.running   { background: #1a4aff33; color: #4a9eff; }
  .status-pill.completed { background: #1acc8833; color: #44cc88; }
  .status-pill.failed    { background: #ff444433; color: #ff5555; }

  .spinner {
    width: 20px;
    height: 20px;
    border: 2px solid #333;
    border-top-color: #4a9eff;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  .history { margin-top: 32px; }
  h3 { font-size: 1rem; color: #888; margin-bottom: 10px; }
  table { width: 100%; border-collapse: collapse; font-size: 0.82rem; }
  th, td { padding: 7px 10px; text-align: left; border-bottom: 1px solid #222; }
  th { color: #666; font-weight: 500; }
  td.path {
    color: #aaa;
    font-family: monospace;
    font-size: 0.78rem;
    max-width: 300px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
</style>
