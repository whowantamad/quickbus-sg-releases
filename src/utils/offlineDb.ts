import { BusStop } from '../types/bus';
import {
  SINGAPORE_BUS_STOPS,
  BUNDLED_VERSION_HASH,
  BUNDLED_ROUTES,
  BUNDLED_FIRST_LAST,
  BundledRouteEntry,
  updateRuntimeTransitCatalog,
  searchBusStops
} from '../data/singaporeBusStops';

const DB_NAME = 'QuickBusSG_Offline_v2';
const DB_VERSION = 2;
const STORE_BUS_STOPS = 'bus_stops';
const STORE_ROUTES = 'bus_routes';
const STORE_FIRST_LAST = 'first_last';
const STORE_METADATA = 'metadata';

export interface OfflineDbStats {
  initialized: boolean;
  count: number;
  routeCount: number;
  versionHash: string;
  lastSynced: number | null;
  source: string;
}

export interface SyncCheckResult {
  upToDate: boolean;
  updated: boolean;
  versionHash: string;
  stopCount: number;
  routeCount: number;
  message: string;
}

function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    if (typeof window === 'undefined' || !window.indexedDB) {
      reject(new Error('IndexedDB not supported'));
      return;
    }

    const request = window.indexedDB.open(DB_NAME, DB_VERSION);

    request.onupgradeneeded = (event) => {
      const db = (event.target as IDBOpenDBRequest).result;

      if (!db.objectStoreNames.contains(STORE_BUS_STOPS)) {
        const stopStore = db.createObjectStore(STORE_BUS_STOPS, { keyPath: 'code' });
        stopStore.createIndex('name', 'name', { unique: false });
        stopStore.createIndex('road', 'road', { unique: false });
      }

      if (!db.objectStoreNames.contains(STORE_ROUTES)) {
        db.createObjectStore(STORE_ROUTES, { keyPath: 'id' });
      }

      if (!db.objectStoreNames.contains(STORE_FIRST_LAST)) {
        db.createObjectStore(STORE_FIRST_LAST, { keyPath: 'id' });
      }

      if (!db.objectStoreNames.contains(STORE_METADATA)) {
        db.createObjectStore(STORE_METADATA, { keyPath: 'id' });
      }
    };

    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

// Initialize the offline database from the bundled 5,208+ stops, 602+ routes & per-stop operating hours snapshot
export async function initOfflineDb(force = false): Promise<OfflineDbStats> {
  try {
    const db = await openDb();
    const meta = await getStoredMetadata(db);

    if (
      !force &&
      meta &&
      meta.initialized &&
      meta.count >= SINGAPORE_BUS_STOPS.length &&
      meta.hasFirstLast
    ) {
      // If IndexedDB has a synced snapshot different from the bundled hash, hydrate memory from IDB
      if (meta.versionHash && meta.versionHash !== BUNDLED_VERSION_HASH) {
        await hydrateRuntimeFromDb(db, meta.versionHash);
      }
      // Perform silent change-detection check in background
      syncTransitDbIfNeeded(true).catch(() => {});
      return {
        initialized: true,
        count: SINGAPORE_BUS_STOPS.length,
        routeCount: Object.keys(BUNDLED_ROUTES).length,
        versionHash: meta.versionHash || BUNDLED_VERSION_HASH,
        lastSynced: meta.lastSynced || Date.now(),
        source: meta.source || 'bundled_app_snapshot'
      };
    }

    // Seed IndexedDB with the bundled 5,208+ stops, 602+ routes & per-stop first/last operating hours
    await saveSnapshotToDb(
      db,
      SINGAPORE_BUS_STOPS,
      BUNDLED_ROUTES,
      BUNDLED_FIRST_LAST,
      BUNDLED_VERSION_HASH,
      'bundled_app_snapshot',
      force
    );

    // Perform silent background check against the change-detection sync server
    syncTransitDbIfNeeded(true).catch(() => {});

    return {
      initialized: true,
      count: SINGAPORE_BUS_STOPS.length,
      routeCount: Object.keys(BUNDLED_ROUTES).length,
      versionHash: BUNDLED_VERSION_HASH,
      lastSynced: Date.now(),
      source: 'bundled_app_snapshot'
    };
  } catch (err) {
    console.warn('IndexedDB initialization fallback to bundled memory store:', err);
    return {
      initialized: true,
      count: SINGAPORE_BUS_STOPS.length,
      routeCount: Object.keys(BUNDLED_ROUTES).length,
      versionHash: BUNDLED_VERSION_HASH,
      lastSynced: Date.now(),
      source: 'memory_bundled'
    };
  }
}

async function getStoredMetadata(db: IDBDatabase): Promise<any | null> {
  return new Promise((resolve) => {
    try {
      const tx = db.transaction(STORE_METADATA, 'readonly');
      const store = tx.objectStore(STORE_METADATA);
      const req = store.get('status');
      req.onsuccess = () => resolve(req.result || null);
      req.onerror = () => resolve(null);
    } catch {
      resolve(null);
    }
  });
}

async function hydrateRuntimeFromDb(db: IDBDatabase, versionHash: string): Promise<void> {
  return new Promise((resolve) => {
    try {
      const tx = db.transaction([STORE_BUS_STOPS, STORE_ROUTES, STORE_FIRST_LAST], 'readonly');
      const stopStore = tx.objectStore(STORE_BUS_STOPS);
      const routeStore = tx.objectStore(STORE_ROUTES);
      const flStore = tx.objectStore(STORE_FIRST_LAST);

      let stops: BusStop[] = [];
      let routes: Record<string, BundledRouteEntry> | undefined;
      let firstLast: Record<string, string[]> | undefined;

      const stopsReq = stopStore.getAll();
      stopsReq.onsuccess = () => {
        stops = stopsReq.result as BusStop[];
      };

      const routesReq = routeStore.get('all_routes');
      routesReq.onsuccess = () => {
        if (routesReq.result?.data) {
          routes = routesReq.result.data;
        }
      };

      const flReq = flStore.get('all_first_last');
      flReq.onsuccess = () => {
        if (flReq.result?.data) {
          firstLast = flReq.result.data;
        }
      };

      tx.oncomplete = () => {
        if (stops.length > 0) {
          updateRuntimeTransitCatalog(stops, routes, versionHash, firstLast);
        }
        resolve();
      };
      tx.onerror = () => resolve();
    } catch {
      resolve();
    }
  });
}

async function saveSnapshotToDb(
  db: IDBDatabase,
  stops: BusStop[],
  routes: Record<string, BundledRouteEntry>,
  firstLast: Record<string, string[]>,
  versionHash: string,
  source: string,
  clearExisting = false
): Promise<void> {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(
      [STORE_BUS_STOPS, STORE_ROUTES, STORE_FIRST_LAST, STORE_METADATA],
      'readwrite'
    );
    const stopStore = tx.objectStore(STORE_BUS_STOPS);
    const routeStore = tx.objectStore(STORE_ROUTES);
    const flStore = tx.objectStore(STORE_FIRST_LAST);
    const metaStore = tx.objectStore(STORE_METADATA);

    if (clearExisting) {
      stopStore.clear();
    }

    for (let i = 0; i < stops.length; i++) {
      stopStore.put(stops[i]);
    }

    routeStore.put({
      id: 'all_routes',
      data: routes
    });

    flStore.put({
      id: 'all_first_last',
      data: firstLast
    });

    metaStore.put({
      id: 'status',
      count: stops.length,
      routeCount: Object.keys(routes).length,
      hasFirstLast: Object.keys(firstLast).length > 0,
      versionHash,
      initialized: true,
      lastSynced: Date.now(),
      source
    });

    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

// Check the sync server and only download/update if the database hash has changed
export async function syncTransitDbIfNeeded(silent = false): Promise<SyncCheckResult> {
  try {
    const currentHash = BUNDLED_VERSION_HASH;
    const res = await fetch(`/api/db-sync?version=${encodeURIComponent(currentHash)}`);
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`);
    }

    const data = await res.json();
    if (data.upToDate) {
      return {
        upToDate: true,
        updated: false,
        versionHash: data.versionHash || currentHash,
        stopCount: SINGAPORE_BUS_STOPS.length,
        routeCount: Object.keys(BUNDLED_ROUTES).length,
        message: `Already up to date (${SINGAPORE_BUS_STOPS.length.toLocaleString()} stops · ${Object.keys(BUNDLED_ROUTES).length} routes).`
      };
    }

    if (Array.isArray(data.stops) && data.stops.length > 0) {
      const nextRoutes = data.routes || BUNDLED_ROUTES;
      const nextFirstLast = data.firstLast || BUNDLED_FIRST_LAST;
      const nextHash = data.versionHash || currentHash;

      updateRuntimeTransitCatalog(data.stops, nextRoutes, nextHash, nextFirstLast);

      const db = await openDb();
      await saveSnapshotToDb(
        db,
        data.stops,
        nextRoutes,
        nextFirstLast,
        nextHash,
        'delta_sync_server',
        true
      );

      return {
        upToDate: false,
        updated: true,
        versionHash: nextHash,
        stopCount: data.stops.length,
        routeCount: Object.keys(nextRoutes).length,
        message: `Updated to ${data.stops.length.toLocaleString()} stops & ${Object.keys(nextRoutes).length} routes.`
      };
    }

    return {
      upToDate: true,
      updated: false,
      versionHash: currentHash,
      stopCount: SINGAPORE_BUS_STOPS.length,
      routeCount: Object.keys(BUNDLED_ROUTES).length,
      message: `Up to date (${SINGAPORE_BUS_STOPS.length.toLocaleString()} stops).`
    };
  } catch (err: any) {
    if (!silent) {
      throw err;
    }
    return {
      upToDate: true,
      updated: false,
      versionHash: BUNDLED_VERSION_HASH,
      stopCount: SINGAPORE_BUS_STOPS.length,
      routeCount: Object.keys(BUNDLED_ROUTES).length,
      message: 'Offline mode active.'
    };
  }
}

export async function getDbStats(): Promise<OfflineDbStats> {
  return {
    initialized: true,
    count: SINGAPORE_BUS_STOPS.length,
    routeCount: Object.keys(BUNDLED_ROUTES).length,
    versionHash: BUNDLED_VERSION_HASH,
    lastSynced: Date.now(),
    source: 'bundled_app_snapshot'
  };
}

export async function searchOfflineDatabase(query: string, limit = 50): Promise<BusStop[]> {
  return searchBusStops(query, limit);
}

export async function insertOfflineStops(stops: BusStop[], source = 'lta_datamall_sync'): Promise<number> {
  updateRuntimeTransitCatalog(stops, BUNDLED_ROUTES, BUNDLED_VERSION_HASH, BUNDLED_FIRST_LAST);
  const db = await openDb();
  await saveSnapshotToDb(
    db,
    stops,
    BUNDLED_ROUTES,
    BUNDLED_FIRST_LAST,
    BUNDLED_VERSION_HASH,
    source,
    false
  );
  return stops.length;
}
