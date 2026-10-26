import { FavoriteStop, UserSettings, ThemeMode } from '../types/bus';

const FAVORITES_KEY = 'quickbus_favorites';
const RECENT_STOPS_KEY = 'quickbus_recent_stops';
const STARRED_SERVICES_KEY = 'quickbus_starred_services';
const SETTINGS_KEY = 'quickbus_settings';

export interface RecentStopRecord {
  code: string;
  count: number;
  lastOpenedAt: number;
}

export const DEFAULT_SETTINGS: UserSettings = {
  datamallKey: '',
  autoRefreshSeconds: 30,
  haptics: true,
  theme: 'system',
  showAndroidFrame: true
};

// Initial favorites so the user doesn't face an empty void on first launch
const INITIAL_FAVORITES: FavoriteStop[] = [
  { code: '03223', customName: 'City Hall Hub', pinnedAt: Date.now() - 100000, tag: 'Work' },
  { code: '09048', customName: 'Orchard Lucky Plaza', pinnedAt: Date.now() - 50000, tag: 'Shopping' },
  { code: '75009', customName: 'Tampines Interchange', pinnedAt: Date.now(), tag: 'Transit' }
];

export function getFavorites(): FavoriteStop[] {
  try {
    const raw = localStorage.getItem(FAVORITES_KEY);
    if (!raw) {
      localStorage.setItem(FAVORITES_KEY, JSON.stringify(INITIAL_FAVORITES));
      return INITIAL_FAVORITES;
    }
    return JSON.parse(raw);
  } catch {
    return INITIAL_FAVORITES;
  }
}

export function saveFavorites(favorites: FavoriteStop[]): void {
  try {
    localStorage.setItem(FAVORITES_KEY, JSON.stringify(favorites));
  } catch (e) {
    console.error('Failed to save favorites to localStorage', e);
  }
}

export function toggleFavorite(code: string, customName?: string, tag?: string): boolean {
  const current = getFavorites();
  const exists = current.some(f => f.code === code);
  let updated: FavoriteStop[];
  if (exists) {
    updated = current.filter(f => f.code !== code);
  } else {
    updated = [{ code, customName: customName || '', pinnedAt: Date.now(), tag: tag || 'Commute' }, ...current];
  }
  saveFavorites(updated);
  return !exists;
}

export function removeFavorite(code: string): void {
  const current = getFavorites();
  const updated = current.filter((f) => f.code !== code);
  saveFavorites(updated);
}

export function isFavorite(code: string): boolean {
  return getFavorites().some(f => f.code === code);
}

export function getRecentStopRecords(): RecentStopRecord[] {
  try {
    const raw = localStorage.getItem(RECENT_STOPS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed
      .filter((item): item is RecentStopRecord => Boolean(item && typeof item.code === 'string' && typeof item.count === 'number'))
      .sort((a, b) => b.count - a.count || (b.lastOpenedAt || 0) - (a.lastOpenedAt || 0));
  } catch {
    return [];
  }
}

export function recordStopOpen(code: string): RecentStopRecord[] {
  const stopCode = code.trim();
  if (!stopCode) return getRecentStopRecords();
  try {
    const current = getRecentStopRecords();
    const existingIndex = current.findIndex((item) => item.code === stopCode);
    const now = Date.now();
    let updated: RecentStopRecord[];
    if (existingIndex >= 0) {
      updated = current.map((item, idx) =>
        idx === existingIndex
          ? { ...item, count: item.count + 1, lastOpenedAt: now }
          : item
      );
    } else {
      updated = [...current, { code: stopCode, count: 1, lastOpenedAt: now }];
    }
    updated.sort((a, b) => b.count - a.count || b.lastOpenedAt - a.lastOpenedAt);
    localStorage.setItem(RECENT_STOPS_KEY, JSON.stringify(updated));
    return updated;
  } catch (e) {
    console.error('Failed to record stop open count', e);
    return getRecentStopRecords();
  }
}

export function removeRecentStopRecord(code: string): RecentStopRecord[] {
  const stopCode = code.trim();
  try {
    const current = getRecentStopRecords();
    const updated = current.filter((item) => item.code !== stopCode);
    localStorage.setItem(RECENT_STOPS_KEY, JSON.stringify(updated));
    return updated;
  } catch (e) {
    console.error('Failed to remove recent stop record', e);
    return getRecentStopRecords();
  }
}

export function getStopOpenCount(code: string): number {
  const found = getRecentStopRecords().find((item) => item.code === code);
  return found ? found.count : 0;
}

function getAllStarredServicesMap(): Record<string, string[]> {
  try {
    const raw = localStorage.getItem(STARRED_SERVICES_KEY);
    if (!raw) return {};
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
}

export function getStarredServicesForStop(stopCode: string): string[] {
  if (!stopCode) return [];
  const map = getAllStarredServicesMap();
  const list = map[stopCode.trim()];
  return Array.isArray(list) ? list : [];
}

export function toggleStarredServiceForStop(stopCode: string, serviceKey: string): string[] {
  const code = stopCode.trim();
  const key = serviceKey.trim();
  if (!code || !key) return [];
  try {
    const map = getAllStarredServicesMap();
    const current = Array.isArray(map[code]) ? map[code] : [];
    const exists = current.includes(key);
    const updated = exists ? current.filter((k) => k !== key) : [...current, key];
    map[code] = updated;
    localStorage.setItem(STARRED_SERVICES_KEY, JSON.stringify(map));
    return updated;
  } catch (e) {
    console.error('Failed to toggle starred bus service', e);
    return getStarredServicesForStop(code);
  }
}

export function getSettings(): UserSettings {
  try {
    const raw = localStorage.getItem(SETTINGS_KEY);
    return raw ? { ...DEFAULT_SETTINGS, ...JSON.parse(raw) } : DEFAULT_SETTINGS;
  } catch {
    return DEFAULT_SETTINGS;
  }
}

export function saveSettings(settings: Partial<UserSettings>): UserSettings {
  try {
    const current = getSettings();
    const updated = { ...current, ...settings };
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(updated));
    return updated;
  } catch {
    return DEFAULT_SETTINGS;
  }
}
