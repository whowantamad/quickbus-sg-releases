import { BusLoad, BusDeckType } from '../types/bus';

// Calculate arrival status in minutes relative to current time
export function calculateArrivalMinutes(isoTimestamp?: string): {
  minutes: number | null;
  display: string;
  isArrived: boolean;
  isImminent: boolean;
} {
  if (!isoTimestamp) {
    return { minutes: null, display: '—', isArrived: false, isImminent: false };
  }

  const arrivalTime = new Date(isoTimestamp).getTime();
  if (isNaN(arrivalTime)) {
    return { minutes: null, display: '—', isArrived: false, isImminent: false };
  }

  const now = Date.now();
  const diffMs = arrivalTime - now;
  const diffMinutes = Math.floor(diffMs / (60 * 1000));

  if (diffMinutes <= 0) {
    return { minutes: 0, display: 'Arr', isArrived: true, isImminent: true };
  } else if (diffMinutes === 1) {
    return { minutes: 1, display: '1', isArrived: false, isImminent: true };
  } else {
    return { minutes: diffMinutes, display: `${diffMinutes}`, isArrived: false, isImminent: diffMinutes <= 3 };
  }
}

// Convert LTA Load codes to human-readable labels and color tokens
export function getLoadDetails(load?: BusLoad): {
  label: string;
  badgeClass: string;
  dotColor: string;
  solidBg: string;
  tintBg: string;
  borderColor: string;
  textColor: string;
} {
  switch (load) {
    case 'SEA':
      return {
        label: 'Seats Available',
        badgeClass: 'text-emerald-700 bg-emerald-50 dark:bg-emerald-950/40 dark:text-emerald-300 border-emerald-200 dark:border-emerald-800/60',
        dotColor: 'bg-emerald-500',
        solidBg: 'bg-emerald-600 text-white',
        tintBg: 'bg-emerald-50 dark:bg-emerald-950/40 text-emerald-800 dark:text-emerald-200 border-emerald-200 dark:border-emerald-800/80',
        borderColor: 'border-emerald-500',
        textColor: 'text-emerald-600 dark:text-emerald-400'
      };
    case 'SDA':
      return {
        label: 'Standing Available',
        badgeClass: 'text-amber-700 bg-amber-50 dark:bg-amber-950/40 dark:text-amber-300 border-amber-200 dark:border-amber-800/60',
        dotColor: 'bg-amber-500',
        solidBg: 'bg-amber-500 text-white',
        tintBg: 'bg-amber-50 dark:bg-amber-950/40 text-amber-800 dark:text-amber-200 border-amber-200 dark:border-amber-800/80',
        borderColor: 'border-amber-500',
        textColor: 'text-amber-600 dark:text-amber-400'
      };
    case 'LSD':
      return {
        label: 'Limited Standing',
        badgeClass: 'text-rose-700 bg-rose-50 dark:bg-rose-950/40 dark:text-rose-300 border-rose-200 dark:border-rose-800/60',
        dotColor: 'bg-rose-500',
        solidBg: 'bg-rose-600 text-white',
        tintBg: 'bg-rose-50 dark:bg-rose-950/40 text-rose-800 dark:text-rose-200 border-rose-200 dark:border-rose-800/80',
        borderColor: 'border-rose-500',
        textColor: 'text-rose-600 dark:text-rose-400'
      };
    default:
      return {
        label: 'No Data',
        badgeClass: 'text-slate-600 bg-slate-100 dark:bg-slate-800 dark:text-slate-300 border-slate-200 dark:border-slate-700',
        dotColor: 'bg-slate-400',
        solidBg: 'bg-slate-700 text-white',
        tintBg: 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-700',
        borderColor: 'border-slate-300 dark:border-slate-700',
        textColor: 'text-slate-500'
      };
  }
}

// Convert LTA Deck Type codes to clean descriptions
export function getDeckTypeDetails(type?: BusDeckType): {
  code: string;
  label: string;
  isDouble: boolean;
} {
  switch (type) {
    case 'DD':
      return { code: 'DD', label: 'Double Deck', isDouble: true };
    case 'BD':
      return { code: 'BD', label: 'Bendy Bus', isDouble: false };
    case 'SD':
    default:
      return { code: 'SD', label: 'Single Deck', isDouble: false };
  }
}

// Format Singapore local time string
export function formatSingaporeTime(date: Date = new Date()): string {
  return new Intl.DateTimeFormat('en-SG', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
    timeZone: 'Asia/Singapore'
  }).format(date);
}
