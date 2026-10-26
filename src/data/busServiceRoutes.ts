import { SINGAPORE_BUS_STOPS, BUNDLED_ROUTES, BUNDLED_FIRST_LAST, getBusStopByCode } from './singaporeBusStops';
import { BusStop, BusArrivalService } from '../types/bus';

export interface BusSchedule {
  weekday: { first: string; last: string };
  saturday: { first: string; last: string };
  sunday: { first: string; last: string };
  frequency: {
    morningPeak: string;
    eveningPeak: string;
    offPeak: string;
  };
}

export interface BusRouteInfo {
  serviceNo: string;
  operator: string;
  origin: string;
  destination: string;
  isLoop?: boolean;
  isDualLoop?: boolean;
  direction1Name: string;
  direction2Name?: string;
  schedule: BusSchedule;
  direction1Stops: BusStop[];
  direction2Stops?: BusStop[];
}

interface DualLoopWingMeta {
  interchangeCodes: string[];
  splitIndex?: number;
  wing1Label: string;
  wing2Label: string;
  swapDisplayOrder?: boolean;
}

// Concise single-road labels for Singapore dual-loop feeder services
export const DUAL_LOOP_CONFIG: Record<string, DualLoopWingMeta> = {
  '358': {
    interchangeCodes: ['77009'],
    wing1Label: 'Pasir Ris Dr 10',
    wing2Label: 'Pasir Ris Dr 4',
    swapDisplayOrder: true
  },
  '359': {
    interchangeCodes: ['77009'],
    wing1Label: 'Pasir Ris St 71',
    wing2Label: 'Pasir Ris St 21',
    swapDisplayOrder: true
  },
  '291': {
    interchangeCodes: ['75009'],
    wing1Label: 'Tampines St 81',
    wing2Label: 'Tampines St 33',
    swapDisplayOrder: true
  },
  '293': {
    interchangeCodes: ['75009'],
    wing1Label: 'Tampines St 71',
    wing2Label: 'Tampines St 42',
    swapDisplayOrder: true
  },
  '811': {
    interchangeCodes: ['59009', '59072', '59159'],
    splitIndex: 24,
    wing1Label: 'Yishun Ave 6',
    wing2Label: 'Yishun Ave 5'
  },
  '812': {
    interchangeCodes: ['59009'],
    wing1Label: 'Yishun Ave 4',
    wing2Label: 'Yishun Ave 2'
  },
  '911': {
    interchangeCodes: ['46009', '46008'],
    wing1Label: 'Woodlands Ave 1',
    wing2Label: 'Woodlands Ctr Rd'
  },
  '912': {
    interchangeCodes: ['46009', '46008'],
    wing1Label: 'Woodlands Ave 7',
    wing2Label: 'Woodlands Ctr Rd'
  },
  '913': {
    interchangeCodes: ['46009', '46008'],
    wing1Label: 'Woodlands Ave 6',
    wing2Label: 'Woodlands Ctr Rd'
  }
};

export const KNOWN_BUS_SCHEDULES: Record<string, BusSchedule> = {
  '147': {
    weekday: { first: '05:30', last: '23:45' },
    saturday: { first: '05:30', last: '23:45' },
    sunday: { first: '05:45', last: '23:30' },
    frequency: {
      morningPeak: '5 - 8 mins',
      eveningPeak: '6 - 9 mins',
      offPeak: '8 - 12 mins'
    }
  },
  '65': {
    weekday: { first: '05:30', last: '23:30' },
    saturday: { first: '05:30', last: '23:30' },
    sunday: { first: '05:45', last: '23:30' },
    frequency: {
      morningPeak: '6 - 9 mins',
      eveningPeak: '7 - 10 mins',
      offPeak: '9 - 13 mins'
    }
  },
  '190': {
    weekday: { first: '05:30', last: '23:30' },
    saturday: { first: '05:30', last: '23:30' },
    sunday: { first: '05:45', last: '23:30' },
    frequency: {
      morningPeak: '4 - 7 mins',
      eveningPeak: '5 - 8 mins',
      offPeak: '7 - 11 mins'
    }
  },
  '358': {
    weekday: { first: '05:15', last: '00:35' },
    saturday: { first: '05:15', last: '00:35' },
    sunday: { first: '05:30', last: '00:35' },
    frequency: {
      morningPeak: '5 - 7 mins',
      eveningPeak: '5 - 8 mins',
      offPeak: '8 - 12 mins'
    }
  }
};

// Return a single concise road name (or stop name if road is missing) at the loop midpoint
function getMidpointRoadName(stops: BusStop[]): string {
  if (stops.length === 0) return 'Terminal';
  const midStop = stops[Math.floor(stops.length / 2)];
  if (!midStop) return 'Terminal';
  return midStop.road || midStop.name;
}

// Detect if a single-array route is a figure-8 dual-loop returning to the interchange mid-route
function findDualLoopSplitIndex(dir1Codes: string[], serviceNo: string): number {
  const config = DUAL_LOOP_CONFIG[serviceNo];
  if (config?.splitIndex && config.splitIndex < dir1Codes.length - 2) {
    return config.splitIndex;
  }

  if (dir1Codes.length < 14) return -1;
  const firstCode = dir1Codes[0];
  const lastCode = dir1Codes[dir1Codes.length - 1];
  if (firstCode !== lastCode) return -1;

  const firstStop = getBusStopByCode(firstCode);
  for (let i = 6; i <= dir1Codes.length - 6; i++) {
    const code = dir1Codes[i];
    if (code === firstCode) return i;
    if (firstStop) {
      const s = getBusStopByCode(code);
      if (s && s.name === firstStop.name) return i;
    }
  }
  return -1;
}

export function isDualLoopAtStop(serviceNo: string, stopCode: string): boolean {
  const config = DUAL_LOOP_CONFIG[serviceNo];
  if (config && config.interchangeCodes.includes(stopCode)) {
    return true;
  }

  const bundled = BUNDLED_ROUTES[serviceNo];
  if (bundled && Array.isArray(bundled.routes) && bundled.routes.length === 1) {
    const dir1Codes = bundled.routes[0] || [];
    const splitIdx = findDualLoopSplitIndex(dir1Codes, serviceNo);
    if (splitIdx !== -1) {
      const firstCode = dir1Codes[0];
      const midCode = dir1Codes[splitIdx];
      return stopCode === firstCode || stopCode === midCode;
    }
  }
  return false;
}

function formatRawBusTime(raw?: string): string {
  if (!raw || raw === '-' || !/^\d{4}$/.test(raw)) return '—';
  if (raw === '2400') return '00:00';
  return `${raw.slice(0, 2)}:${raw.slice(2, 4)}`;
}

/**
 * Look up the exact First & Last bus operating schedule for a specific (serviceNo, stopCode)
 * from the offline database (BUNDLED_FIRST_LAST).
 */
export function getStopServiceSchedule(
  serviceNo: string,
  stopCode?: string,
  loopWing?: 1 | 2
): BusSchedule {
  const svcNo = serviceNo.trim();
  const isFeederPattern = /^(2\d\d|3\d\d|80\d|81\d|90\d|91\d|92\d)/i.test(svcNo);
  const isPeakOrShortTrip =
    /^(65\d|66\d|67\d)$/i.test(svcNo) || /^\d+[ABCeTWXabcewx]$/.test(svcNo);

  const defaultFrequency = isPeakOrShortTrip
    ? {
        morningPeak: '8 - 15 mins',
        eveningPeak: '8 - 15 mins',
        offPeak: 'Peak Hours Only'
      }
    : isFeederPattern
    ? {
        morningPeak: '5 - 8 mins',
        eveningPeak: '5 - 8 mins',
        offPeak: '8 - 12 mins'
      }
    : {
        morningPeak: '6 - 9 mins',
        eveningPeak: '7 - 10 mins',
        offPeak: '9 - 13 mins'
      };

  const bundled = BUNDLED_ROUTES[svcNo];
  const originStopCode = bundled?.routes?.[0]?.[0];
  const candidateStopCodes = [stopCode?.trim(), originStopCode].filter(
    (c): c is string => Boolean(c)
  );

  for (const targetCode of candidateStopCodes) {
    const stopEntries = BUNDLED_FIRST_LAST[targetCode];
    if (!Array.isArray(stopEntries) || stopEntries.length === 0) continue;

    const matches = stopEntries.filter((line) => {
      const firstSpace = line.indexOf(' ');
      const entrySvc = firstSpace !== -1 ? line.slice(0, firstSpace) : line;
      return entrySvc === svcNo;
    });

    if (matches.length > 0) {
      let chosenLine = matches[0];

      // For Dual-Loop interchanges where both loop wings have distinct departure rows
      if (matches.length > 1 && loopWing) {
        const config = DUAL_LOOP_CONFIG[svcNo];
        if (config && config.interchangeCodes.includes(targetCode)) {
          if (config.swapDisplayOrder) {
            chosenLine = loopWing === 1 ? matches[1] || matches[0] : matches[0];
          } else {
            chosenLine = loopWing === 2 ? matches[1] || matches[0] : matches[0];
          }
        }
      }

      const parts = chosenLine.trim().split(/\s+/);
      if (parts.length >= 7) {
        const wd1 = parts[1];
        const wd2 = parts[2];
        const sat1 = parts[3] === '=' ? wd1 : parts[3];
        const sat2 = parts[4] === '=' ? wd2 : parts[4];
        const sun1 = parts[5] === '=' ? wd1 : parts[5];
        const sun2 = parts[6] === '=' ? wd2 : parts[6];

        return {
          weekday: {
            first: formatRawBusTime(wd1),
            last: formatRawBusTime(wd2)
          },
          saturday: {
            first: formatRawBusTime(sat1),
            last: formatRawBusTime(sat2)
          },
          sunday: {
            first: formatRawBusTime(sun1),
            last: formatRawBusTime(sun2)
          },
          frequency: KNOWN_BUS_SCHEDULES[svcNo]?.frequency || defaultFrequency
        };
      }
    }
  }

  return (
    KNOWN_BUS_SCHEDULES[svcNo] ||
    (isPeakOrShortTrip
      ? {
          weekday: { first: '06:30', last: '19:30' },
          saturday: { first: '—', last: '—' },
          sunday: { first: '—', last: '—' },
          frequency: defaultFrequency
        }
      : isFeederPattern
      ? {
          weekday: { first: '05:15', last: '00:35' },
          saturday: { first: '05:15', last: '00:35' },
          sunday: { first: '05:30', last: '00:35' },
          frequency: defaultFrequency
        }
      : {
          weekday: { first: '05:30', last: '23:45' },
          saturday: { first: '05:30', last: '23:45' },
          sunday: { first: '05:45', last: '23:30' },
          frequency: defaultFrequency
        })
  );
}

export function getBusRouteAndSchedule(
  serviceNo: string,
  stopCode?: string,
  loopWing?: 1 | 2
): BusRouteInfo {
  const bundled = BUNDLED_ROUTES[serviceNo];
  const defaultSchedule: BusSchedule = getStopServiceSchedule(serviceNo, stopCode, loopWing);

  if (bundled && Array.isArray(bundled.routes) && bundled.routes.length > 0) {
    const dir1Codes = bundled.routes[0] || [];
    const dir2Codes = bundled.routes[1];

    // Check if this is a Figure-8 Dual-Loop route (e.g., 358, 359, 291, 293, 811, 812, 911, 912, 913)
    if (!dir2Codes || dir2Codes.length === 0) {
      const splitIdx = findDualLoopSplitIndex(dir1Codes, serviceNo);
      if (splitIdx !== -1) {
        const rawWing1Stops = dir1Codes
          .slice(0, splitIdx + 1)
          .map((code) => getBusStopByCode(code))
          .filter((s): s is BusStop => Boolean(s));
        const rawWing2Stops = dir1Codes
          .slice(splitIdx)
          .map((code) => getBusStopByCode(code))
          .filter((s): s is BusStop => Boolean(s));

        const config = DUAL_LOOP_CONFIG[serviceNo];
        const origin = rawWing1Stops[0]?.name || 'Interchange';

        const w1Label = config?.wing1Label || getMidpointRoadName(rawWing1Stops);
        const w2Label = config?.wing2Label || getMidpointRoadName(rawWing2Stops);

        if (config?.swapDisplayOrder) {
          return {
            serviceNo,
            operator: '',
            origin,
            destination: w2Label,
            isLoop: true,
            isDualLoop: true,
            direction1Name: w2Label,
            direction2Name: w1Label,
            schedule: defaultSchedule,
            direction1Stops: rawWing2Stops,
            direction2Stops: rawWing1Stops
          };
        }

        return {
          serviceNo,
          operator: '',
          origin,
          destination: w1Label,
          isLoop: true,
          isDualLoop: true,
          direction1Name: w1Label,
          direction2Name: w2Label,
          schedule: defaultSchedule,
          direction1Stops: rawWing1Stops,
          direction2Stops: rawWing2Stops
        };
      }
    }

    const dir1Stops = dir1Codes
      .map((code) => getBusStopByCode(code))
      .filter((s): s is BusStop => Boolean(s));

    const dir2Stops =
      Array.isArray(dir2Codes) && dir2Codes.length > 0
        ? dir2Codes
            .map((code) => getBusStopByCode(code))
            .filter((s): s is BusStop => Boolean(s))
        : undefined;

    const origin = dir1Stops[0]?.name || 'Terminal';
    const rawDest = dir1Stops[dir1Stops.length - 1]?.name || 'Terminal';
    const isSingleLoop =
      !dir2Stops &&
      dir1Stops.length > 2 &&
      (dir1Stops[0]?.code === dir1Stops[dir1Stops.length - 1]?.code ||
        origin === rawDest ||
        Boolean(bundled.name && bundled.name.includes('⟲')));

    if (isSingleLoop) {
      const midpointRoad = getMidpointRoadName(dir1Stops);
      const isFeederLoop =
        /^(2\d\d|3\d\d|80\d|81\d|90\d|91\d|92\d)/i.test(serviceNo) ||
        dir1Stops.length <= 24;

      if (!isFeederLoop && dir1Stops.length >= 25) {
        const midIdx = Math.floor(dir1Stops.length / 2);
        const outboundStops = dir1Stops.slice(0, midIdx + 1);
        const inboundStops = dir1Stops.slice(midIdx);

        return {
          serviceNo,
          operator: '',
          origin,
          destination: midpointRoad,
          isLoop: false,
          isDualLoop: false,
          direction1Name: midpointRoad,
          direction2Name: origin,
          schedule: defaultSchedule,
          direction1Stops: outboundStops,
          direction2Stops: inboundStops
        };
      }

      return {
        serviceNo,
        operator: '',
        origin,
        destination: midpointRoad,
        isLoop: true,
        isDualLoop: false,
        direction1Name: midpointRoad,
        schedule: defaultSchedule,
        direction1Stops: dir1Stops
      };
    }

    return {
      serviceNo,
      operator: '',
      origin,
      destination: rawDest,
      isLoop: false,
      isDualLoop: false,
      direction1Name: rawDest,
      direction2Name: dir2Stops ? (dir2Stops[dir2Stops.length - 1]?.name || origin) : undefined,
      schedule: defaultSchedule,
      direction1Stops: dir1Stops,
      direction2Stops: dir2Stops
    };
  }

  // Fallback if service is not in BUNDLED_ROUTES
  const matchingStops = SINGAPORE_BUS_STOPS.filter((stop) =>
    stop.services.includes(serviceNo)
  );
  const stops = matchingStops.length > 0 ? matchingStops : SINGAPORE_BUS_STOPS.slice(0, 12);
  const origin = stops[0]?.name || 'Terminal';
  const destination = stops[stops.length - 1]?.name || 'Terminal';

  return {
    serviceNo,
    operator: '',
    origin,
    destination,
    direction1Name: destination,
    direction2Name: origin,
    schedule: defaultSchedule,
    direction1Stops: stops,
    direction2Stops: [...stops].reverse()
  };
}

// Resolve concise 1-item road or terminal name for a bus service at a specific bus stop
export function resolveBusServiceDirection(
  service: BusArrivalService,
  currentStopCode?: string
): {
  label: string;
  isLoop: boolean;
} {
  // 1. If explicit loopDirectionLabel is already attached (e.g. split Dual-Loop row at Interchange)
  if (service.loopDirectionLabel) {
    return {
      label: service.loopDirectionLabel,
      isLoop: true
    };
  }

  const route = getBusRouteAndSchedule(service.ServiceNo);

  // 2. Dual-Loop Service handling
  if (route.isDualLoop) {
    if (service.loopWing === 1) {
      return { label: route.direction1Name, isLoop: true };
    }
    if (service.loopWing === 2 && route.direction2Name) {
      return { label: route.direction2Name, isLoop: true };
    }

    if (currentStopCode) {
      const idx1 = route.direction1Stops.findIndex((s) => s.code === currentStopCode);
      const idx2 = route.direction2Stops
        ? route.direction2Stops.findIndex((s) => s.code === currentStopCode)
        : -1;

      if (idx1 > 0 && idx1 < route.direction1Stops.length - 1) {
        const half1 = Math.floor(route.direction1Stops.length * 0.55);
        if (idx1 < half1) {
          return { label: route.direction1Name, isLoop: true };
        } else {
          return { label: route.origin, isLoop: false };
        }
      }

      if (idx2 > 0 && route.direction2Stops && idx2 < route.direction2Stops.length - 1) {
        const half2 = Math.floor(route.direction2Stops.length * 0.55);
        if (idx2 < half2) {
          return { label: route.direction2Name || route.direction1Name, isLoop: true };
        } else {
          return { label: route.origin, isLoop: false };
        }
      }
    }

    return { label: route.direction1Name, isLoop: true };
  }

  // 3. Bidirectional Trunk Service (including split turnaround routes like Bus 53)
  if (route.direction2Stops && route.direction2Stops.length > 0) {
    if (currentStopCode) {
      const inDir1 = route.direction1Stops.findIndex((s) => s.code === currentStopCode);
      const inDir2 = route.direction2Stops.findIndex((s) => s.code === currentStopCode);

      if (
        (inDir2 !== -1 && inDir1 === -1) ||
        (inDir1 === route.direction1Stops.length - 1 && inDir2 === 0)
      ) {
        return {
          label:
            route.direction2Name ||
            route.direction2Stops[route.direction2Stops.length - 1]?.name ||
            route.origin,
          isLoop: false
        };
      }
      if (inDir1 !== -1 && inDir1 < route.direction1Stops.length - 1) {
        return {
          label:
            route.direction1Name ||
            route.direction1Stops[route.direction1Stops.length - 1]?.name ||
            route.destination,
          isLoop: false
        };
      }
    }

    return {
      label: route.direction1Name || route.destination,
      isLoop: false
    };
  }

  // 4. Single-Loop Feeder Service handling
  const b1 = service.NextBus || service.NextBus2 || service.NextBus3;
  const destCode = b1?.DestinationCode;
  const originCode = b1?.OriginCode;
  const isSameOriginDest = Boolean(destCode && originCode && destCode === originCode);
  const isDestSameAsCurrent = Boolean(destCode && currentStopCode && destCode === currentStopCode);

  if (route.isLoop || isSameOriginDest || isDestSameAsCurrent) {
    const stops = route.direction1Stops;
    if (stops.length > 2 && currentStopCode) {
      const idx = stops.findIndex((s) => s.code === currentStopCode);
      const turnIdx = Math.floor(stops.length * 0.55);

      // If boarding AFTER the loop turning point, show the terminal name
      if (idx >= turnIdx && idx < stops.length - 1) {
        return {
          label: route.origin,
          isLoop: false
        };
      }
    }

    // At the interchange or on the outbound leg towards the loop midpoint: show 1 concise road name
    return {
      label: getMidpointRoadName(stops),
      isLoop: true
    };
  }

  if (destCode) {
    const stopMatch = getBusStopByCode(destCode);
    if (stopMatch?.name) {
      return { label: stopMatch.name, isLoop: false };
    }
  }

  return { label: route.destination, isLoop: false };
}

function parseTimeToMinutes(timeStr?: string): number | null {
  if (!timeStr || !timeStr.includes(':')) return null;
  const [hStr, mStr] = timeStr.split(':');
  const h = parseInt(hStr, 10);
  const m = parseInt(mStr, 10);
  if (Number.isNaN(h) || Number.isNaN(m)) return null;
  return h * 60 + m;
}

function isWithinWindow(
  currentMinutes: number,
  firstMin: number | null,
  lastMin: number | null
): boolean {
  if (firstMin === null || lastMin === null) return false;
  if (lastMin < firstMin) {
    // Runs past midnight (e.g. 05:15 - 00:35 or 05:30 - 00:00)
    return currentMinutes >= firstMin || currentMinutes <= lastMin;
  }
  return currentMinutes >= firstMin && currentMinutes <= lastMin;
}

/**
 * Determines whether a bus service at a specific bus stop is currently within its scheduled
 * operating hours in Singapore Time (SGT / Asia/Singapore), using the per-service, per-stop
 * schedule stored in the offline database.
 */
export function isServiceInOperation(
  service: BusArrivalService,
  stopCode?: string,
  now: Date = new Date()
): boolean {
  const svcNo = service.ServiceNo.trim();

  // Extract current day of week and time in Singapore (Asia/Singapore)
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Singapore',
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  });

  const parts = formatter.formatToParts(now);
  const weekdayPart = parts.find((p) => p.type === 'weekday')?.value || 'Mon';
  const hourPart = parseInt(parts.find((p) => p.type === 'hour')?.value || '12', 10) % 24;
  const minutePart = parseInt(parts.find((p) => p.type === 'minute')?.value || '0', 10);
  const currentMinutes = hourPart * 60 + minutePart;

  const isSunday = weekdayPart === 'Sun';
  const isSaturday = weekdayPart === 'Sat';

  // Look up the exact per-service, per-stop schedule from the offline database
  const schedule = getStopServiceSchedule(svcNo, stopCode, service.loopWing);

  const todaySchedule = isSunday
    ? schedule.sunday
    : isSaturday
    ? schedule.saturday
    : schedule.weekday;

  const todayFirst = parseTimeToMinutes(todaySchedule.first);
  const todayLast = parseTimeToMinutes(todaySchedule.last);

  if (isWithinWindow(currentMinutes, todayFirst, todayLast)) {
    return true;
  }

  // Also check if current time is in the post-midnight tail (00:00 - 03:59) of yesterday's schedule
  if (currentMinutes < 4 * 60) {
    const yesterdaySchedule =
      weekdayPart === 'Mon'
        ? schedule.sunday
        : weekdayPart === 'Sun'
        ? schedule.saturday
        : schedule.weekday;
    const yFirst = parseTimeToMinutes(yesterdaySchedule.first);
    const yLast = parseTimeToMinutes(yesterdaySchedule.last);
    if (yFirst !== null && yLast !== null && yLast < yFirst && currentMinutes <= yLast) {
      return true;
    }
  }

  return false;
}

/**
 * Returns the LTA DataMall v3 recommended advisement text when no arrival data is available:
 * - Scenario (b): Bus is in operation at this stop + Arrival data NOT available -> "No Est. Available"
 * - Scenario (c): Bus is NOT in operation at this stop + Arrival data NOT available -> "Not In Operation"
 */
export function getNoArrivalAdvisement(
  service: BusArrivalService,
  stopCode?: string,
  now: Date = new Date()
): 'No Est. Available' | 'Not In Operation' {
  return isServiceInOperation(service, stopCode, now) ? 'No Est. Available' : 'Not In Operation';
}

