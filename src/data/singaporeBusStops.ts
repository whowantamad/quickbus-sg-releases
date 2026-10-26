import { BusStop } from '../types/bus';
import rawSnapshot from './sgTransitSnapshot.json';

export interface BundledRouteEntry {
  name: string;
  routes: string[][];
}

export interface TransitSnapshot {
  versionHash: string;
  generatedAt: string;
  stopCount: number;
  routeCount: number;
  stops: BusStop[];
  routes: Record<string, BundledRouteEntry>;
  firstLast?: Record<string, string[]>;
}

const initialSnapshot = rawSnapshot as unknown as TransitSnapshot;

// Complete bundled 5,208+ Singapore bus stops, 602+ routes, and per-stop first/last bus timings
export let SINGAPORE_BUS_STOPS: BusStop[] = initialSnapshot.stops;
export let BUNDLED_VERSION_HASH: string = initialSnapshot.versionHash;
export let BUNDLED_ROUTES: Record<string, BundledRouteEntry> = initialSnapshot.routes;
export let BUNDLED_FIRST_LAST: Record<string, string[]> = initialSnapshot.firstLast || {};

// Fast O(1) lookup map by 5-digit bus stop code
let stopByCodeMap = new Map<string, BusStop>(
  SINGAPORE_BUS_STOPS.map((s) => [s.code, s])
);

// Update in-memory catalog when a newer snapshot is synced from the change-detection server or IndexedDB
export function updateRuntimeTransitCatalog(
  stops: BusStop[],
  routes?: Record<string, BundledRouteEntry>,
  versionHash?: string,
  firstLast?: Record<string, string[]>
) {
  if (Array.isArray(stops) && stops.length > 0) {
    SINGAPORE_BUS_STOPS = stops;
    stopByCodeMap = new Map<string, BusStop>(stops.map((s) => [s.code, s]));
  }
  if (routes && Object.keys(routes).length > 0) {
    BUNDLED_ROUTES = routes;
  }
  if (firstLast && Object.keys(firstLast).length > 0) {
    BUNDLED_FIRST_LAST = firstLast;
  }
  if (versionHash) {
    BUNDLED_VERSION_HASH = versionHash;
  }
}

// Offline fuzzy search across Stop Code, Stop Name, Road, or Servicing Bus Numbers
export function searchBusStops(query: string, limit = 50): BusStop[] {
  const q = query.trim().toLowerCase();
  if (!q) return SINGAPORE_BUS_STOPS.slice(0, limit);

  // Exact 5-digit bus stop code match takes immediate top precedence
  if (/^\d{5}$/.test(q)) {
    const exact = stopByCodeMap.get(q);
    if (exact) {
      const remaining = SINGAPORE_BUS_STOPS.filter(
        (s) =>
          s.code !== q &&
          (s.code.includes(q) ||
            s.name.toLowerCase().includes(q) ||
            s.road.toLowerCase().includes(q))
      ).slice(0, limit - 1);
      return [exact, ...remaining];
    }
  }

  const results: BusStop[] = [];
  for (let i = 0; i < SINGAPORE_BUS_STOPS.length; i++) {
    const stop = SINGAPORE_BUS_STOPS[i];
    const matchCode = stop.code.includes(q);
    const matchName = stop.name.toLowerCase().includes(q);
    const matchRoad = stop.road.toLowerCase().includes(q);
    const matchMrt = stop.mrtNearby?.toLowerCase().includes(q) || false;
    const matchService = stop.services.some(
      (svc) => svc.toLowerCase() === q || svc.toLowerCase().startsWith(q)
    );
    if (matchCode || matchName || matchRoad || matchMrt || matchService) {
      results.push(stop);
      if (results.length >= limit) break;
    }
  }
  return results;
}

// Find single bus stop by code in O(1)
export function getBusStopByCode(code: string): BusStop | undefined {
  if (!code) return undefined;
  return stopByCodeMap.get(code.trim());
}

// Haversine distance formula in meters
function haversineDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371e3; // Earth radius in meters
  const phi1 = (lat1 * Math.PI) / 180;
  const phi2 = (lat2 * Math.PI) / 180;
  const deltaPhi = ((lat2 - lat1) * Math.PI) / 180;
  const deltaLambda = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
    Math.cos(phi1) * Math.cos(phi2) * Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return Math.round(R * c);
}

// Find closest stops to user's geolocation across all 5,208+ Singapore stops
export function getNearestBusStops(lat: number, lng: number, count = 15): BusStop[] {
  return SINGAPORE_BUS_STOPS.map((stop) => ({
    ...stop,
    distance: haversineDistance(lat, lng, stop.lat, stop.lng)
  }))
    .sort((a, b) => (a.distance || 0) - (b.distance || 0))
    .slice(0, count);
}

// Extract unique list of all 600+ bus services servicing Singapore
export function getAllAvailableServices(): string[] {
  const routeKeys = Object.keys(BUNDLED_ROUTES);
  if (routeKeys.length > 0) {
    return routeKeys.sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
  }
  const set = new Set<string>();
  SINGAPORE_BUS_STOPS.forEach((stop) => {
    stop.services.forEach((svc) => set.add(svc));
  });
  return Array.from(set).sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
}
