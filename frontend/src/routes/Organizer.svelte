<script>
  import { startOrganize, getOrganizeJob, pickDestinationDirectory, onEvent, offEvent } from '../lib/wailsbridge.js'

  let destRoot   = ''
  let folderFmt  = 'YYYY/MM/DD'
  let dryRun     = true
  let running    = false
  let job        = null
  let results    = []
  let error      = ''

  const ACTION_LABELS = {
    copy:             { icon: '📋', label: 'Copy',              color: '#44cc88' },
    skip_exists:      { icon: '⏭',  label: 'Skip (exists)',     color: '#4a9eff' },
    skip_duplicate:   { icon: '🔁',  label: 'Skip (duplicate)',  color: '#ff9944' },
    rename_conflict:  { icon: '✏️',  label: 'Rename (conflict)', color: '#ffcc44' },
  }

  async function browseDest() {
    try {
      const path = await pickDestinationDirectory()
      if (path) destRoot = path
    } catch (e) {
      error = e.message
    }
  }

  async function submit() {
    if (!destRoot.trim()) return
    error = ''
    running = true
    job = null
    results = []
    try {
      const res = await startOrganize({
        destination_root: destRoot.trim(),
        folder_format: folderFmt,
        dry_run: dryRun,
      })
      job = { id: res.job_id, status: 'running' }

      onEvent('organize:progress', (payload) => {
        job     = payload.job
        results = payload.results ?? []
      })
      onEvent('organize:done', (payload) => {
        job     = payload.job
        results = payload.results ?? []
        running = false
        offEvent('organize:progress', 'organize:done')
      })
    } catch (e) {
      error = e.message
      running = false
    }
  }

  function basename(path) {
    return path?.split('/')?.pop() ?? path
  }

  $: actionCounts = results.reduce((acc, r) => {
    acc[r.action] = (acc[r.action] ?? 0) + 1
    return acc
  }, {})
</script>

<div class="page">
  <h2>Organize Photos</h2>
  <p class="hint">
    Copies photos into a date-based folder structure. Originals are <strong>never moved or deleted</strong>.
    Already-existing identical files are skipped. Only one file per duplicate group is copied.
  </p>

  <form class="form" on:submit|preventDefault={submit}>
    <div class="field">
      <label for="dest">Destination folder</label>
      <div class="dest-row">
        <input
          id="dest"
          type="text"
          bind:value={destRoot}
          placeholder="/Volumes/Organized"
          disabled={running}
        />
        <button type="button" class="browse-btn" on:click={browseDest} disabled={running}>
          Browse
        </button>
      </div>
    </div>

    <div class="field">
      <label for="fmt">Folder structure</label>
      <select id="fmt" bind:value={folderFmt} disabled={running}>
        <option value="YYYY/MM/DD">YYYY/MM/DD</option>
        <option value="YYYY/MM">YYYY/MM</option>
        <option value="YYYY">YYYY</option>
      </select>
      <span class="fmt-preview">→ e.g. <code>{folderFmt.replace('YYYY','2023').replace('MM','07').replace('DD','04')}/IMG_1234.jpg</code></span>
    </div>

    <div class="field row">
      <label class="toggle">
        <input type="checkbox" bind:checked={dryRun} disabled={running} />
        <span>Dry run (preview only, no files copied)</span>
      </label>
    </div>

    <button type="submit" disabled={running || !destRoot.trim()} class:dry={dryRun}>
      {running ? 'Running…' : dryRun ? '🔍 Preview' : '📋 Copy Files'}
    </button>
  </form>

  {#if error}
    <p class="err">{error}</p>
  {/if}

  {#if job}
    <div class="job-card" class:dry={job?.dry_run !== false} class:done={job.status === 'completed'}>
      <div class="job-header">
        <span>Job #{job.id}</span>
        <span class="pill {job.status}">{job.status}</span>
        {#if job.dry_run !== false}<span class="pill dry">DRY RUN</span>{/if}
        {#if running}<span class="spinner-sm"></span>{/if}
      </div>

      <div class="stats">
        <div class="stat"><span class="n">{job.total_files ?? 0}</span><span class="l">Total</span></div>
        <div class="stat green"><span class="n">{job.copied_files ?? 0}</span><span class="l">{job.dry_run !== false ? 'Would copy' : 'Copied'}</span></div>
        <div class="stat muted"><span class="n">{job.skipped_files ?? 0}</span><span class="l">Skipped</span></div>
      </div>

      {#if Object.keys(actionCounts).length > 0}
        <div class="action-counts">
          {#each Object.entries(actionCounts) as [action, n]}
            {@const info = ACTION_LABELS[action] ?? { icon: '?', label: action, color: '#888' }}
            <span class="ac" style="--c:{info.color}">{info.icon} {info.label}: <strong>{n}</strong></span>
          {/each}
        </div>
      {/if}
    </div>

    {#if results.length > 0}
      <div class="results-table">
        <h3>File-by-file results</h3>
        <table>
          <thead>
            <tr>
              <th>Action</th>
              <th>Source</th>
              <th>Destination</th>
              <th>Reason</th>
            </tr>
          </thead>
          <tbody>
            {#each results as r (r.id)}
              {@const info = ACTION_LABELS[r.action] ?? { icon: '?', label: r.action, color: '#888' }}
              <tr>
                <td><span class="action-badge" style="color:{info.color}">{info.icon} {info.label}</span></td>
                <td class="path" title={r.source}>{basename(r.source)}</td>
                <td class="path" title={r.destination}>{r.destination}</td>
                <td class="reason">{r.reason ?? ''}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}
  {/if}
</div>

<style>
  .page { padding: 24px; max-width: 980px; overflow-y: auto; height: 100%; }
  h2    { margin: 0 0 6px; }
  .hint { color: #888; font-size: 0.88rem; margin: 0 0 24px; }
  .hint strong { color: #ccc; }

  .form { display: flex; flex-direction: column; gap: 14px; max-width: 600px; }
  .field { display: flex; flex-direction: column; gap: 5px; }
  .field label { font-size: 0.8rem; color: #888; }
  .field input, .field select {
    background: #1a1a1a; border: 1px solid #333; color: #ddd;
    padding: 9px 12px; border-radius: 4px; font-size: 0.9rem;
  }
  .field input:focus, .field select:focus { outline: none; border-color: #4a9eff; }
  .fmt-preview { font-size: 0.75rem; color: #666; }
  .fmt-preview code { color: #aaa; }

  .dest-row { display: flex; gap: 8px; }
  .dest-row input { flex: 1; }
  .browse-btn {
    background: #2a2a2a; border: 1px solid #444; color: #ccc;
    padding: 9px 16px; border-radius: 4px; cursor: pointer; font-size: 0.9rem;
    white-space: nowrap;
  }
  .browse-btn:hover:not(:disabled) { border-color: #666; color: #eee; }
  .browse-btn:disabled { opacity: 0.4; cursor: default; }

  .field.row { flex-direction: row; align-items: center; }
  .toggle { display: flex; align-items: center; gap: 8px; font-size: 0.85rem; color: #aaa; cursor: pointer; }
  .toggle input { accent-color: #4a9eff; }

  form button[type="submit"] {
    align-self: flex-start;
    background: #44cc88;
    border: none; color: #000;
    padding: 10px 22px;
    border-radius: 4px;
    font-weight: 600;
    cursor: pointer;
    font-size: 0.9rem;
  }
  form button[type="submit"].dry { background: #4a9eff; }
  form button[type="submit"]:disabled { opacity: 0.4; cursor: default; }

  .err { color: #ff5555; font-size: 0.85rem; margin-top: 4px; }

  .job-card {
    margin-top: 24px;
    background: #141414;
    border: 1px solid #2a2a2a;
    border-radius: 8px;
    overflow: hidden;
    max-width: 600px;
  }
  .job-card.done { border-color: #44cc8844; }

  .job-header {
    padding: 10px 16px;
    background: #1a1a1a;
    border-bottom: 1px solid #222;
    display: flex; align-items: center; gap: 8px;
    font-size: 0.82rem; color: #888;
  }

  .pill {
    padding: 2px 8px;
    border-radius: 10px;
    font-size: 0.68rem; font-weight: 700; text-transform: uppercase;
  }
  .pill.running   { background: #1a4aff22; color: #4a9eff; }
  .pill.completed { background: #1acc8822; color: #44cc88; }
  .pill.failed    { background: #ff444422; color: #ff5555; }
  .pill.dry       { background: #ffcc4422; color: #ffcc44; }

  .spinner-sm {
    width: 14px; height: 14px; margin-left: auto;
    border: 2px solid #333; border-top-color: #4a9eff;
    border-radius: 50%; animation: spin 0.8s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  .stats { display: flex; padding: 14px 16px; gap: 28px; }
  .stat { display: flex; flex-direction: column; align-items: center; gap: 2px; }
  .stat .n { font-size: 1.6rem; font-weight: 700; line-height: 1; }
  .stat .l { font-size: 0.68rem; color: #666; }
  .stat.green .n { color: #44cc88; }
  .stat.muted .n { color: #888; }

  .action-counts { padding: 0 16px 14px; display: flex; flex-wrap: wrap; gap: 10px; }
  .ac {
    font-size: 0.75rem;
    color: var(--c, #888);
    background: color-mix(in srgb, var(--c) 12%, transparent);
    padding: 2px 8px;
    border-radius: 10px;
  }

  .results-table { margin-top: 28px; }
  h3 { font-size: 0.9rem; color: #666; margin-bottom: 8px; }
  table { width: 100%; border-collapse: collapse; font-size: 0.78rem; }
  th, td { padding: 7px 10px; text-align: left; border-bottom: 1px solid #1e1e1e; }
  th { color: #555; font-weight: 500; }
  .path { font-family: monospace; color: #aaa; max-width: 260px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .reason { color: #666; max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .action-badge { font-size: 0.75rem; white-space: nowrap; }
</style>
