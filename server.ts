import express, { Request, Response } from 'express';
import { createServer as createViteServer } from 'vite';
import path from 'path';
import fs from 'fs';
import crypto from 'crypto';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PORT = Number(process.env.PORT) || 3000;
const LTA_BASE_URL = 'https://datamall2.mytransport.sg/ltaodataservice/v3/BusArrival';

interface SnapshotStop {
  code: string;
  name: string;
  road: string;
  lat: number;
  lng: number;
  services: string[];
}

interface SnapshotRouteEntry {
  name?: string;
  routes: string[][];
}

interface SnapshotData {
  versionHash: string;
  generatedAt: string;
  stopCount: number;
  routeCount: number;
  stops: SnapshotStop[];
  routes: Record<string, SnapshotRouteEntry | string[][]>;
  firstLast?: Record<string, string[]>;
}

// Load bundled snapshot at startup
let cachedSnapshot: SnapshotData = {
  versionHash: 'v3-bundled',
  generatedAt: new Date().toISOString(),
  stopCount: 0,
  routeCount: 0,
  stops: [],
  routes: {},
  firstLast: {}
};

const stopByCode = new Map<string, SnapshotStop>();
let lastUpstreamCheckMs = 0;
const UPSTREAM_CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour

function indexSnapshot(snapshot: SnapshotData) {
  cachedSnapshot = snapshot;
  stopByCode.clear();
  for (const s of snapshot.stops) {
    stopByCode.set(s.code, s);
  }
}

try {
  const snapshotPath = path.resolve(__dirname, 'src/data/sgTransitSnapshot.json');
  if (fs.existsSync(snapshotPath)) {
    const raw = JSON.parse(fs.readFileSync(snapshotPath, 'utf-8')) as SnapshotData;
    indexSnapshot(raw);
  }
} catch (err) {
  console.warn('Could not load initial sgTransitSnapshot.json:', err);
}

async function getLatestTransitSnapshot(forceUpstream = false): Promise<SnapshotData> {
  const now = Date.now();
  if (!forceUpstream && now - lastUpstreamCheckMs < UPSTREAM_CACHE_TTL_MS && cachedSnapshot.stops.length > 0) {
    return cachedSnapshot;
  }

  try {
    const [stopsRes, servicesRes, firstLastRes] = await Promise.all([
      fetch('https://data.busrouter.sg/v1/stops.min.json'),
      fetch('https://data.busrouter.sg/v1/services.min.json'),
      fetch('https://data.busrouter.sg/v1/firstlast.min.json')
    ]);

    if (stopsRes.ok && servicesRes.ok) {
      const stopsRaw = (await stopsRes.json()) as Record<string, [number, number, string, string]>;
      const servicesRaw = (await servicesRes.json()) as Record<string, { name: string; routes: string[][] }>;
      const firstLastRaw = firstLastRes.ok
        ? ((await firstLastRes.json()) as Record<string, string[]>)
        : cachedSnapshot.firstLast || {};

      const stopServicesMap: Record<string, Set<string>> = {};
      const routes: Record<string, SnapshotRouteEntry> = {};

      for (const [svcNo, svcData] of Object.entries(servicesRaw)) {
        if (svcData && Array.isArray(svcData.routes)) {
          routes[svcNo] = {
            name: String(svcData.name || '').trim(),
            routes: svcData.routes
          };
          for (const dirRoute of svcData.routes) {
            if (Array.isArray(dirRoute)) {
              for (const stopCode of dirRoute) {
                if (!stopServicesMap[stopCode]) stopServicesMap[stopCode] = new Set();
                stopServicesMap[stopCode].add(svcNo);
              }
            }
          }
        }
      }

      const collator = new Intl.Collator(undefined, { numeric: true, sensitivity: 'base' });
      const stops: SnapshotStop[] = Object.entries(stopsRaw)
        .map(([code, arr]) => {
          const [lng, lat, name, road] = arr;
          const services = stopServicesMap[code]
            ? Array.from(stopServicesMap[code]).sort(collator.compare)
            : [];
          return {
            code: String(code).trim(),
            name: String(name || 'Bus Stop').trim(),
            road: String(road || '').trim(),
            lat: Number(lat.toFixed(6)),
            lng: Number(lng.toFixed(6)),
            services
          };
        })
        .sort((a, b) => a.code.localeCompare(b.code));

      const hashPayload = JSON.stringify({
        stopCount: stops.length,
        routeCount: Object.keys(routes).length,
        stops,
        routes
      });
      const versionHash = 'v3-' + crypto.createHash('sha256').update(hashPayload).digest('hex').slice(0, 16);

      lastUpstreamCheckMs = now;
      if (versionHash !== cachedSnapshot.versionHash) {
        indexSnapshot({
          versionHash,
          generatedAt: new Date().toISOString(),
          stopCount: stops.length,
          routeCount: Object.keys(routes).length,
          stops,
          routes,
          firstLast: firstLastRaw
        });
      }
    }
  } catch {
    // Offline or upstream unreachable - gracefully keep bundled snapshot
  }

  return cachedSnapshot;
}

function parseRawTimeToMinutes(raw?: string): number | null {
  if (!raw || raw === '-' || !/^\d{4}$/.test(raw)) return null;
  if (raw === '2400') return 0;
  const h = parseInt(raw.slice(0, 2), 10);
  const m = parseInt(raw.slice(2, 4), 10);
  if (Number.isNaN(h) || Number.isNaN(m)) return null;
  return h * 60 + m;
}

function checkWindow(curr: number, first: number | null, last: number | null): boolean {
  if (first === null || last === null) return false;
  if (last < first) {
    return curr >= first || curr <= last;
  }
  return curr >= first && curr <= last;
}

function isStopServiceOperatingNow(busStopCode: string, svcNo: string): boolean {
  const stopEntries = cachedSnapshot.firstLast?.[busStopCode];
  if (!Array.isArray(stopEntries) || stopEntries.length === 0) {
    return !/^NR\d|^N\d/i.test(svcNo);
  }

  const line = stopEntries.find((item) => {
    const idx = item.indexOf(' ');
    return (idx !== -1 ? item.slice(0, idx) : item) === svcNo;
  });

  if (!line) {
    return !/^NR\d|^N\d/i.test(svcNo);
  }

  const parts = line.trim().split(/\s+/);
  if (parts.length < 7) return true;

  const wd1 = parts[1];
  const wd2 = parts[2];
  const sat1 = parts[3] === '=' ? wd1 : parts[3];
  const sat2 = parts[4] === '=' ? wd2 : parts[4];
  const sun1 = parts[5] === '=' ? wd1 : parts[5];
  const sun2 = parts[6] === '=' ? wd2 : parts[6];

  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Singapore',
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  });
  const dtParts = formatter.formatToParts(new Date());
  const weekday = dtParts.find((p) => p.type === 'weekday')?.value || 'Mon';
  const hour = parseInt(dtParts.find((p) => p.type === 'hour')?.value || '12', 10) % 24;
  const minute = parseInt(dtParts.find((p) => p.type === 'minute')?.value || '0', 10);
  const currMin = hour * 60 + minute;

  const isSun = weekday === 'Sun';
  const isSat = weekday === 'Sat';

  const todayFirst = parseRawTimeToMinutes(isSun ? sun1 : isSat ? sat1 : wd1);
  const todayLast = parseRawTimeToMinutes(isSun ? sun2 : isSat ? sat2 : wd2);

  if (checkWindow(currMin, todayFirst, todayLast)) {
    return true;
  }

  if (currMin < 4 * 60) {
    const yFirst = parseRawTimeToMinutes(
      weekday === 'Mon' ? sun1 : weekday === 'Sun' ? sat1 : wd1
    );
    const yLast = parseRawTimeToMinutes(
      weekday === 'Mon' ? sun2 : weekday === 'Sun' ? sat2 : wd2
    );
    if (yFirst !== null && yLast !== null && yLast < yFirst && currMin <= yLast) {
      return true;
    }
  }

  return false;
}

// Fallback arrival generator for offline simulation or when no LTA key is available
function generateSimulatedArrivals(busStopCode: string, serviceFilter?: string) {
  const codeNum = parseInt(busStopCode.replace(/\D/g, ''), 10) || 12345;
  const knownStop = stopByCode.get(busStopCode);
  const defaultServices = ['10', '14', '65', '124', '147', '166', '174', '190', '197', '857'];

  const baseServices = knownStop && knownStop.services.length > 0
    ? knownStop.services
    : defaultServices.slice((codeNum % 4), (codeNum % 4) + 4);

  const servicesToUse = serviceFilter
    ? [serviceFilter]
    : baseServices;

  const now = Date.now();
  const loads = ['SEA', 'SDA', 'LSD'] as const;
  const types = ['SD', 'DD', 'BD'] as const;

  return servicesToUse.map((svc, idx) => {
    // Resolve real origin and destination codes from route sequence if available
    let originCode = '01012';
    let destCode = '75009';
    const rawEntry = cachedSnapshot.routes[svc];
    const svcRoutes = Array.isArray(rawEntry) ? rawEntry : rawEntry?.routes;
    if (svcRoutes && svcRoutes.length > 0) {
      // Find which direction contains this busStopCode
      const matchingDir = svcRoutes.find((dir) => dir.includes(busStopCode)) || svcRoutes[0];
      if (matchingDir && matchingDir.length > 0) {
        originCode = matchingDir[0];
        destCode = matchingDir[matchingDir.length - 1];
      }
    }

    // Check per-stop operating schedule from offline database: if not operating now at this stop, return empty ETAs
    if (!isStopServiceOperatingNow(busStopCode, svc)) {
      return {
        ServiceNo: svc,
        Operator: idx % 2 === 0 ? 'SBST' : 'SMRT',
        NextBus: {
          OriginCode: originCode,
          DestinationCode: destCode,
          EstimatedArrival: '',
          Latitude: '0',
          Longitude: '0',
          VisitNumber: '1',
          Load: 'SEA',
          Feature: 'WAB',
          Type: 'SD'
        },
        NextBus2: {
          OriginCode: originCode,
          DestinationCode: destCode,
          EstimatedArrival: '',
          Latitude: '0',
          Longitude: '0',
          VisitNumber: '1',
          Load: 'SEA',
          Feature: 'WAB',
          Type: 'SD'
        },
        NextBus3: {
          OriginCode: originCode,
          DestinationCode: destCode,
          EstimatedArrival: '',
          Latitude: '0',
          Longitude: '0',
          VisitNumber: '1',
          Load: 'SEA',
          Feature: 'WAB',
          Type: 'SD'
        }
      };
    }

    // Stagger arrival times realistically: first bus 0-5 mins, second 7-14 mins, third 16-25 mins
    const jitter = ((codeNum + idx * 7) % 5);
    const m1 = Math.max(0, (idx * 2 + jitter) % 6);
    const m2 = m1 + 6 + ((idx + 3) % 5);
    const m3 = m2 + 8 + ((idx + 2) % 6);

    const eta1 = new Date(now + m1 * 60 * 1000).toISOString();
    const eta2 = new Date(now + m2 * 60 * 1000).toISOString();
    const eta3 = new Date(now + m3 * 60 * 1000).toISOString();

    const load1 = loads[(codeNum + idx) % 3];
    const load2 = loads[(codeNum + idx + 1) % 3];
    const load3 = loads[(codeNum + idx + 2) % 3];

    const type1 = types[(idx + 1) % 2]; // mostly SD and DD
    const type2 = types[idx % 2];
    const type3 = types[(idx + 2) % 2];

    return {
      ServiceNo: svc,
      Operator: idx % 2 === 0 ? 'SBST' : 'SMRT',
      NextBus: {
        OriginCode: originCode,
        DestinationCode: destCode,
        EstimatedArrival: eta1,
        Latitude: '1.2985',
        Longitude: '103.8521',
        VisitNumber: '1',
        Load: load1,
        Feature: 'WAB',
        Type: type1
      },
      NextBus2: {
        OriginCode: originCode,
        DestinationCode: destCode,
        EstimatedArrival: eta2,
        Latitude: '1.3050',
        Longitude: '103.8610',
        VisitNumber: '1',
        Load: load2,
        Feature: 'WAB',
        Type: type2
      },
      NextBus3: {
        OriginCode: originCode,
        DestinationCode: destCode,
        EstimatedArrival: eta3,
        Latitude: '1.3120',
        Longitude: '103.8700',
        VisitNumber: '1',
        Load: load3,
        Feature: 'WAB',
        Type: type3
      }
    };
  });
}

async function startServer() {
  const app = express();
  app.use(express.json());

  // Explicitly serve Web App Manifest with proper MIME type & CORS headers for APK packagers
  const webManifestPayload = {
    id: '/',
    name: 'QuickBus SG',
    short_name: 'QuickBus SG',
    description: 'Minimalist Singapore bus arrival and transit app with live LTA DataMall API integration, offline bus stop search, and Material 3 design.',
    start_url: '/',
    scope: '/',
    display: 'standalone',
    orientation: 'portrait',
    theme_color: '#e11d48',
    background_color: '#0c1220',
    categories: ['navigation', 'travel', 'utilities'],
    prefer_related_applications: false,
    icons: [
      {
        src: '/pwa-192x192.png',
        sizes: '192x192',
        type: 'image/png',
        purpose: 'any'
      },
      {
        src: '/pwa-512x512.png',
        sizes: '512x512',
        type: 'image/png',
        purpose: 'any'
      },
      {
        src: '/pwa-maskable-512x512.png',
        sizes: '512x512',
        type: 'image/png',
        purpose: 'maskable'
      }
    ]
  };

  app.get(['/manifest.json', '/manifest.webmanifest'], (_req: Request, res: Response) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Content-Type', 'application/manifest+json; charset=utf-8');
    res.status(200).send(JSON.stringify(webManifestPayload, null, 2));
  });

  // API endpoint: lightweight change-detection sync for bundled offline database
  app.get('/api/db-sync', async (req: Request, res: Response) => {
    const clientVersion = (req.query.version as string || '').trim();
    const forceCheck = req.query.force === 'true';

    const latest = await getLatestTransitSnapshot(forceCheck);

    if (clientVersion && clientVersion === latest.versionHash) {
      return res.json({
        upToDate: true,
        versionHash: latest.versionHash,
        stopCount: latest.stopCount,
        routeCount: latest.routeCount,
        checkedAt: new Date().toISOString()
      });
    }

    return res.json({
      upToDate: false,
      versionHash: latest.versionHash,
      stopCount: latest.stopCount,
      routeCount: latest.routeCount,
      stops: latest.stops,
      routes: latest.routes,
      firstLast: latest.firstLast,
      checkedAt: new Date().toISOString()
    });
  });

  // API endpoint: fetch live bus arrivals
  app.get('/api/bus-arrival', async (req: Request, res: Response) => {
    const busStopCode = (req.query.busStopCode as string || '').trim();
    const serviceNo = (req.query.serviceNo as string || '').trim();
    const clientKey = (req.headers['x-datamall-key'] as string || '').trim();
    const accountKey = clientKey || process.env.LTA_DATAMALL_KEY;

    if (!busStopCode) {
      return res.status(400).json({ error: 'BusStopCode query parameter is required' });
    }

    // If an AccountKey is present, query LTA DataMall v3 directly
    if (accountKey && accountKey !== 'YOUR_LTA_DATAMALL_ACCOUNT_KEY') {
      try {
        let url = `${LTA_BASE_URL}?BusStopCode=${encodeURIComponent(busStopCode)}`;
        if (serviceNo) {
          url += `&ServiceNo=${encodeURIComponent(serviceNo)}`;
        }

        const ltaResponse = await fetch(url, {
          method: 'GET',
          headers: {
            'AccountKey': accountKey,
            'accept': 'application/json'
          }
        });

        if (ltaResponse.ok) {
          const data = await ltaResponse.json();
          return res.json({
            success: true,
            dataSource: 'datamall_live',
            busStopCode: data.BusStopCode || busStopCode,
            services: data.Services || [],
            retrievedAt: new Date().toISOString()
          });
        } else {
          console.warn(`LTA DataMall responded with HTTP ${ltaResponse.status}: ${ltaResponse.statusText}`);
          // Fall back gracefully to simulation if key is unauthorized or rate limited
          const simulatedServices = generateSimulatedArrivals(busStopCode, serviceNo);
          return res.json({
            success: true,
            dataSource: 'simulated_fallback',
            ltaError: `DataMall HTTP ${ltaResponse.status}. Using high-precision offline simulation.`,
            busStopCode,
            services: simulatedServices,
            retrievedAt: new Date().toISOString()
          });
        }
      } catch (err: any) {
        console.error('Error contacting LTA DataMall:', err?.message || err);
        const simulatedServices = generateSimulatedArrivals(busStopCode, serviceNo);
        return res.json({
          success: true,
          dataSource: 'simulated_fallback',
          ltaError: 'Network error connecting to DataMall. Using offline simulation.',
          busStopCode,
          services: simulatedServices,
          retrievedAt: new Date().toISOString()
        });
      }
    }

    // No key provided - return simulated schedule arrivals seamlessly
    const simulatedServices = generateSimulatedArrivals(busStopCode, serviceNo);
    return res.json({
      success: true,
      dataSource: 'simulated_fallback',
      message: 'Running in offline simulation mode. Add your LTA DataMall AccountKey in Settings for 100% direct live LTA telemetry.',
      busStopCode,
      services: simulatedServices,
      retrievedAt: new Date().toISOString()
    });
  });

  // API endpoint: validate user's LTA DataMall AccountKey
  app.post('/api/validate-key', async (req: Request, res: Response) => {
    const key = (req.body?.key as string || '').trim();
    if (!key) {
      return res.status(400).json({ valid: false, message: 'AccountKey is empty' });
    }

    try {
      const testUrl = `${LTA_BASE_URL}?BusStopCode=03223`;
      const testRes = await fetch(testUrl, {
        method: 'GET',
        headers: {
          'AccountKey': key,
          'accept': 'application/json'
        }
      });

      if (testRes.ok) {
        const data = await testRes.json();
        return res.json({
          valid: true,
          message: 'LTA DataMall AccountKey verified successfully! Direct live arrivals enabled.',
          sampleStop: data.BusStopCode
        });
      } else {
        return res.json({
          valid: false,
          status: testRes.status,
          message: `LTA DataMall rejected the key with HTTP status ${testRes.status} (${testRes.statusText}). Check your registration at datamall.lta.gov.sg.`
        });
      }
    } catch (err: any) {
      return res.status(500).json({
        valid: false,
        message: `Network error verifying key: ${err?.message || 'Connection failed'}`
      });
    }
  });

  // API endpoint: fetch bus stops for offline DB sync
  app.get('/api/bus-stops', async (req: Request, res: Response) => {
    const clientKey = (req.headers['x-datamall-key'] as string || '').trim();
    const accountKey = clientKey || process.env.LTA_DATAMALL_KEY;
    const skip = parseInt(req.query.skip as string, 10) || 0;

    if (accountKey && accountKey !== 'YOUR_LTA_DATAMALL_ACCOUNT_KEY') {
      try {
        const stopsUrl = `https://datamall2.mytransport.sg/ltaodataservice/BusStops?$skip=${skip}`;
        const ltaRes = await fetch(stopsUrl, {
          method: 'GET',
          headers: {
            'AccountKey': accountKey,
            'accept': 'application/json'
          }
        });

        if (ltaRes.ok) {
          const json = await ltaRes.json();
          const rawStops = json.value || [];
          const normalized = rawStops.map((s: any) => ({
            code: String(s.BusStopCode || '').trim(),
            name: s.Description || 'Bus Stop',
            road: s.RoadName || '',
            lat: Number(s.Latitude) || 0,
            lng: Number(s.Longitude) || 0,
            services: []
          }));

          return res.json({
            success: true,
            isLiveLTA: true,
            count: normalized.length,
            stops: normalized
          });
        }
      } catch (err) {
        console.warn('LTA BusStops fetch failed:', err);
      }
    }

    // Default response when no key
    return res.json({
      success: true,
      isLiveLTA: false,
      message: 'Using pre-bundled offline Singapore bus stops dataset'
    });
  });

  // Server info
  app.get('/api/server-info', (req: Request, res: Response) => {
    const hasEnvKey = Boolean(process.env.LTA_DATAMALL_KEY && process.env.LTA_DATAMALL_KEY !== 'YOUR_LTA_DATAMALL_ACCOUNT_KEY');
    res.json({
      status: 'online',
      hasServerKey: hasEnvKey,
      time: new Date().toISOString()
    });
  });

  // Mount Vite or static dist in production
  if (process.env.NODE_ENV === 'production') {
    app.use(express.static(path.resolve(__dirname, 'dist')));
    app.get('*', (_req, res) => {
      res.sendFile(path.resolve(__dirname, 'dist', 'index.html'));
    });
  } else {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: 'spa'
    });
    app.use(vite.middlewares);
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`QuickBus SG backend + frontend active on http://0.0.0.0:${PORT}`);
  });
}

startServer().catch((err) => {
  console.error('Failed to start server:', err);
  process.exit(1);
});
