const BASE = '/api'

async function request(method, path, body) {
  const opts = {
    method,
    headers: { 'Content-Type': 'application/json' },
  }
  if (body !== undefined) opts.body = JSON.stringify(body)
  const res = await fetch(BASE + path, opts)
  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: res.statusText }))
    throw new Error(err.error || res.statusText)
  }
  // 204 No Content
  if (res.status === 204) return null
  return res.json()
}

const get  = (path)        => request('GET',  path)
const post = (path, body)  => request('POST', path, body)

// ---- Scan -------------------------------------------------------------------
export const startScan    = (rootPath) => post('/scan', { root_path: rootPath })
export const getScan      = (id)       => get(`/scan/${id}`)
export const listScans    = ()         => get('/scan')

// ---- Photos -----------------------------------------------------------------
export const listPhotos   = (params = {}) => {
  const q = new URLSearchParams()
  if (params.status)       q.set('status',        params.status)
  if (params.cameraModel)  q.set('camera_model',  params.cameraModel)
  if (params.dateFrom)     q.set('date_from',      params.dateFrom)
  if (params.dateTo)       q.set('date_to',        params.dateTo)
  if (params.hasDuplicates !== undefined)
                           q.set('has_duplicates', String(params.hasDuplicates))
  if (params.limit)        q.set('limit',          String(params.limit))
  if (params.offset)       q.set('offset',         String(params.offset))
  const qs = q.toString()
  return get(`/photos${qs ? '?' + qs : ''}`)
}
export const getPhoto      = (id)     => get(`/photos/${id}`)
export const thumbnailUrl  = (id)     => `/api/thumbnails/${id}`

// ---- Duplicates -------------------------------------------------------------
export const listDuplicates = ()                    => get('/duplicates')
export const resolveDuplicate = (groupId, keptId)   => post(`/duplicates/${groupId}/resolve`, { kept_photo_id: keptId })

// ---- Organize ---------------------------------------------------------------
export const startOrganize  = (opts) => post('/organize', opts)
export const getOrganizeJob = (id)   => get(`/organize/${id}`)
