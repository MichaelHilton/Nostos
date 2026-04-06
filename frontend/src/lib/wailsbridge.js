// wailsbridge.js — replaces api.js for the Wails native app.
// All HTTP fetch calls are replaced with direct Go method bindings via
// window.go.main.App.* which Wails injects into the webview at runtime.

const Go = () => window.go.main.App

// ---- Directory pickers ------------------------------------------------------
export const pickDirectory         = () => Go().PickDirectory()
export const pickDestinationDirectory = () => Go().PickDestinationDirectory()

// ---- Scan -------------------------------------------------------------------
export const startScan  = (rootPath) => Go().StartScan(rootPath)
export const getScan    = (id)       => Go().GetScan(id)
export const listScans  = ()         => Go().ListScans()

// ---- Photos -----------------------------------------------------------------
export const listPhotos = (params = {}) => Go().ListPhotos({
  status:         params.status        ?? '',
  camera_model:   params.cameraModel   ?? '',
  date_from:      params.dateFrom      ?? '',
  date_to:        params.dateTo        ?? '',
  has_duplicates: params.hasDuplicates ?? null,
  limit:          params.limit         ?? 50,
  offset:         params.offset        ?? 0,
})
export const getPhoto             = (id) => Go().GetPhoto(id)
export const getThumbnailDataURL  = (id) => Go().GetThumbnailDataURL(id)

// ---- Duplicates -------------------------------------------------------------
export const listDuplicates   = ()                  => Go().ListDuplicates()
export const resolveDuplicate = (groupId, keptId)   => Go().ResolveDuplicate(groupId, keptId)

// ---- Organize ---------------------------------------------------------------
export const startOrganize   = (opts) => Go().StartOrganize(opts)
export const getOrganizeJob  = (id)   => Go().GetOrganizeJob(id)

// ---- Events (Wails runtime) -------------------------------------------------
// Wails v2 injects window.runtime into the webview at startup.
// EventsOn/EventsOff are used instead of HTTP polling.
export function onEvent(name, cb) {
  window.runtime.EventsOn(name, cb)
}
export function offEvent(...names) {
  names.forEach(n => window.runtime.EventsOff(n))
}
