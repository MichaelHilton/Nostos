export namespace db {
	
	export class Photo {
	    id: number;
	    path: string;
	    hash: string;
	    file_size: number;
	    width: number;
	    height: number;
	    // Go type: time
	    taken_at?: any;
	    camera_make: string;
	    camera_model: string;
	    gps_lat?: number;
	    gps_lon?: number;
	    thumbnail_path: string;
	    duplicate_group_id?: number;
	    is_kept: boolean;
	    status: string;
	    // Go type: time
	    scanned_at: any;
	    scan_run_id?: number;
	
	    static createFrom(source: any = {}) {
	        return new Photo(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.path = source["path"];
	        this.hash = source["hash"];
	        this.file_size = source["file_size"];
	        this.width = source["width"];
	        this.height = source["height"];
	        this.taken_at = this.convertValues(source["taken_at"], null);
	        this.camera_make = source["camera_make"];
	        this.camera_model = source["camera_model"];
	        this.gps_lat = source["gps_lat"];
	        this.gps_lon = source["gps_lon"];
	        this.thumbnail_path = source["thumbnail_path"];
	        this.duplicate_group_id = source["duplicate_group_id"];
	        this.is_kept = source["is_kept"];
	        this.status = source["status"];
	        this.scanned_at = this.convertValues(source["scanned_at"], null);
	        this.scan_run_id = source["scan_run_id"];
	    }
	
		convertValues(a: any, classs: any, asMap: boolean = false): any {
		    if (!a) {
		        return a;
		    }
		    if (a.slice && a.map) {
		        return (a as any[]).map(elem => this.convertValues(elem, classs));
		    } else if ("object" === typeof a) {
		        if (asMap) {
		            for (const key of Object.keys(a)) {
		                a[key] = new classs(a[key]);
		            }
		            return a;
		        }
		        return new classs(a);
		    }
		    return a;
		}
	}
	export class DuplicateGroup {
	    id: number;
	    reason: string;
	    kept_photo_id?: number;
	    photos: Photo[];
	
	    static createFrom(source: any = {}) {
	        return new DuplicateGroup(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.reason = source["reason"];
	        this.kept_photo_id = source["kept_photo_id"];
	        this.photos = this.convertValues(source["photos"], Photo);
	    }
	
		convertValues(a: any, classs: any, asMap: boolean = false): any {
		    if (!a) {
		        return a;
		    }
		    if (a.slice && a.map) {
		        return (a as any[]).map(elem => this.convertValues(elem, classs));
		    } else if ("object" === typeof a) {
		        if (asMap) {
		            for (const key of Object.keys(a)) {
		                a[key] = new classs(a[key]);
		            }
		            return a;
		        }
		        return new classs(a);
		    }
		    return a;
		}
	}
	export class OrganizeJob {
	    id: number;
	    destination_root: string;
	    folder_format: string;
	    dry_run: boolean;
	    // Go type: time
	    started_at: any;
	    // Go type: time
	    finished_at?: any;
	    status: string;
	    total_files: number;
	    copied_files: number;
	    skipped_files: number;
	
	    static createFrom(source: any = {}) {
	        return new OrganizeJob(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.destination_root = source["destination_root"];
	        this.folder_format = source["folder_format"];
	        this.dry_run = source["dry_run"];
	        this.started_at = this.convertValues(source["started_at"], null);
	        this.finished_at = this.convertValues(source["finished_at"], null);
	        this.status = source["status"];
	        this.total_files = source["total_files"];
	        this.copied_files = source["copied_files"];
	        this.skipped_files = source["skipped_files"];
	    }
	
		convertValues(a: any, classs: any, asMap: boolean = false): any {
		    if (!a) {
		        return a;
		    }
		    if (a.slice && a.map) {
		        return (a as any[]).map(elem => this.convertValues(elem, classs));
		    } else if ("object" === typeof a) {
		        if (asMap) {
		            for (const key of Object.keys(a)) {
		                a[key] = new classs(a[key]);
		            }
		            return a;
		        }
		        return new classs(a);
		    }
		    return a;
		}
	}
	export class OrganizeResult {
	    id: number;
	    job_id: number;
	    photo_id: number;
	    source: string;
	    destination: string;
	    action: string;
	    reason: string;
	
	    static createFrom(source: any = {}) {
	        return new OrganizeResult(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.job_id = source["job_id"];
	        this.photo_id = source["photo_id"];
	        this.source = source["source"];
	        this.destination = source["destination"];
	        this.action = source["action"];
	        this.reason = source["reason"];
	    }
	}
	
	export class ScanRun {
	    id: number;
	    root_path: string;
	    // Go type: time
	    started_at: any;
	    // Go type: time
	    finished_at?: any;
	    photos_found: number;
	    duplicates_found: number;
	    status: string;
	
	    static createFrom(source: any = {}) {
	        return new ScanRun(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.root_path = source["root_path"];
	        this.started_at = this.convertValues(source["started_at"], null);
	        this.finished_at = this.convertValues(source["finished_at"], null);
	        this.photos_found = source["photos_found"];
	        this.duplicates_found = source["duplicates_found"];
	        this.status = source["status"];
	    }
	
		convertValues(a: any, classs: any, asMap: boolean = false): any {
		    if (!a) {
		        return a;
		    }
		    if (a.slice && a.map) {
		        return (a as any[]).map(elem => this.convertValues(elem, classs));
		    } else if ("object" === typeof a) {
		        if (asMap) {
		            for (const key of Object.keys(a)) {
		                a[key] = new classs(a[key]);
		            }
		            return a;
		        }
		        return new classs(a);
		    }
		    return a;
		}
	}

}

export namespace main {
	
	export class OrganizeJobResult {
	    job?: db.OrganizeJob;
	    results: db.OrganizeResult[];
	
	    static createFrom(source: any = {}) {
	        return new OrganizeJobResult(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.job = this.convertValues(source["job"], db.OrganizeJob);
	        this.results = this.convertValues(source["results"], db.OrganizeResult);
	    }
	
		convertValues(a: any, classs: any, asMap: boolean = false): any {
		    if (!a) {
		        return a;
		    }
		    if (a.slice && a.map) {
		        return (a as any[]).map(elem => this.convertValues(elem, classs));
		    } else if ("object" === typeof a) {
		        if (asMap) {
		            for (const key of Object.keys(a)) {
		                a[key] = new classs(a[key]);
		            }
		            return a;
		        }
		        return new classs(a);
		    }
		    return a;
		}
	}
	export class OrganizeRequest {
	    source_photo_ids: number[];
	    destination_root: string;
	    folder_format: string;
	    dry_run: boolean;
	
	    static createFrom(source: any = {}) {
	        return new OrganizeRequest(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.source_photo_ids = source["source_photo_ids"];
	        this.destination_root = source["destination_root"];
	        this.folder_format = source["folder_format"];
	        this.dry_run = source["dry_run"];
	    }
	}
	export class PhotoQuery {
	    status: string;
	    camera_model: string;
	    date_from: string;
	    date_to: string;
	    has_duplicates?: boolean;
	    limit: number;
	    offset: number;
	
	    static createFrom(source: any = {}) {
	        return new PhotoQuery(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.status = source["status"];
	        this.camera_model = source["camera_model"];
	        this.date_from = source["date_from"];
	        this.date_to = source["date_to"];
	        this.has_duplicates = source["has_duplicates"];
	        this.limit = source["limit"];
	        this.offset = source["offset"];
	    }
	}
	export class PhotosResult {
	    photos: db.Photo[];
	    total: number;
	    offset: number;
	    limit: number;
	
	    static createFrom(source: any = {}) {
	        return new PhotosResult(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.photos = this.convertValues(source["photos"], db.Photo);
	        this.total = source["total"];
	        this.offset = source["offset"];
	        this.limit = source["limit"];
	    }
	
		convertValues(a: any, classs: any, asMap: boolean = false): any {
		    if (!a) {
		        return a;
		    }
		    if (a.slice && a.map) {
		        return (a as any[]).map(elem => this.convertValues(elem, classs));
		    } else if ("object" === typeof a) {
		        if (asMap) {
		            for (const key of Object.keys(a)) {
		                a[key] = new classs(a[key]);
		            }
		            return a;
		        }
		        return new classs(a);
		    }
		    return a;
		}
	}
	export class ScanResult {
	    scan_run_id: number;
	    status: string;
	
	    static createFrom(source: any = {}) {
	        return new ScanResult(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.scan_run_id = source["scan_run_id"];
	        this.status = source["status"];
	    }
	}
	export class StartOrganizeResult {
	    job_id: number;
	    status: string;
	
	    static createFrom(source: any = {}) {
	        return new StartOrganizeResult(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.job_id = source["job_id"];
	        this.status = source["status"];
	    }
	}

}

