export interface BusStop {
  code: string;
  name: string;
  road: string;
  lat: number;
  lng: number;
  services: string[];
  mrtNearby?: string;
  distance?: number; // distance in meters from user, if geolocated
}

export type BusLoad = 'SEA' | 'SDA' | 'LSD' | string; // Seats Available, Standing Available, Limited Standing
export type BusDeckType = 'SD' | 'DD' | 'BD' | string; // Single Deck, Double Deck, Bendy

export interface NextBusInfo {
  OriginCode?: string;
  DestinationCode?: string;
  EstimatedArrival?: string; // ISO string e.g. 2026-10-24T18:25:00+08:00
  Latitude?: string;
  Longitude?: string;
  VisitNumber?: string;
  Load?: BusLoad;
  Feature?: string; // 'WAB'
  Type?: BusDeckType;
}

export interface BusArrivalService {
  ServiceNo: string;
  Operator: string;
  NextBus?: NextBusInfo;
  NextBus2?: NextBusInfo;
  NextBus3?: NextBusInfo;
  loopWing?: 1 | 2;
  loopDirectionLabel?: string;
  routeKey?: string;
}

export interface ArrivalApiResponse {
  success: boolean;
  dataSource: 'datamall_live' | 'simulated_fallback';
  busStopCode: string;
  services: BusArrivalService[];
  retrievedAt: string;
  ltaError?: string;
  message?: string;
}

export interface FavoriteStop {
  code: string;
  customName?: string;
  pinnedAt: number;
  tag?: string;
}

export type ThemeMode = 'light' | 'dark' | 'system';

export interface UserSettings {
  datamallKey: string;
  autoRefreshSeconds: number; // 0 (disabled), 15, 30, 60
  haptics: boolean;
  theme: ThemeMode;
  showAndroidFrame: boolean;
}
