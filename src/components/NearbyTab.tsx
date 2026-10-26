import React, { useState, useEffect } from 'react';
import { BusStop } from '../types/bus';
import { getNearestBusStops } from '../data/singaporeBusStops';
import { StopListItem } from './StopListItem';
import { Navigation, LocateFixed, AlertCircle } from 'lucide-react';

interface NearbyTabProps {
  onSelectStop: (stop: BusStop) => void;
}

const SG_HUBS = [
  { name: 'City Hall', lat: 1.2929, lng: 103.8529 },
  { name: 'Orchard', lat: 1.3040, lng: 103.8340 },
  { name: 'Raffles Place', lat: 1.2858, lng: 103.8528 },
  { name: 'Bugis', lat: 1.3005, lng: 103.8565 },
  { name: 'Tampines', lat: 1.3533, lng: 103.9452 },
  { name: 'Jurong East', lat: 1.3331, lng: 103.7423 },
  { name: 'Woodlands', lat: 1.4368, lng: 103.7865 },
  { name: 'Bedok', lat: 1.3243, lng: 103.9304 }
];

export const NearbyTab: React.FC<NearbyTabProps> = ({ onSelectStop }) => {
  const [selectedHub, setSelectedHub] = useState<string>('City Hall');
  const [stops, setStops] = useState<BusStop[]>([]);
  const [isLocating, setIsLocating] = useState<boolean>(false);
  const [geoError, setGeoError] = useState<string | null>(null);
  const [usingGps, setUsingGps] = useState<boolean>(false);

  const loadForCoords = (lat: number, lng: number, label?: string) => {
    const nearest = getNearestBusStops(lat, lng, 15);
    setStops(nearest);
    if (label) setSelectedHub(label);
  };

  useEffect(() => {
    const defaultHub = SG_HUBS[0];
    loadForCoords(defaultHub.lat, defaultHub.lng, defaultHub.name);
  }, []);

  const handleUseGps = () => {
    if (!navigator.geolocation) {
      setGeoError('Geolocation unavailable');
      return;
    }

    setIsLocating(true);
    setGeoError(null);

    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setIsLocating(false);
        setUsingGps(true);
        setSelectedHub('GPS');
        loadForCoords(pos.coords.latitude, pos.coords.longitude, 'GPS');
      },
      (err) => {
        setIsLocating(false);
        console.warn('Geolocation error:', err.message);
        setGeoError('GPS access denied');
      },
      { timeout: 8000, enableHighAccuracy: true }
    );
  };

  return (
    <div className="flex-1 flex flex-col h-full overflow-y-auto px-4 py-4 pb-20">
      {/* Top Header */}
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          <Navigation className="w-5 h-5 text-rose-500" />
          <h2 className="text-base font-extrabold text-slate-900 dark:text-slate-50">
            Nearby
          </h2>
          <span className="text-xs text-slate-400">· {selectedHub}</span>
        </div>

        {/* GPS Trigger Button (Icon-focused) */}
        <button
          onClick={handleUseGps}
          disabled={isLocating}
          className={`w-9 h-9 rounded-full flex items-center justify-center transition-all shadow-xs ${
            usingGps
              ? 'bg-emerald-600 text-white'
              : 'bg-rose-600 text-white hover:bg-rose-700'
          }`}
          title={usingGps ? 'GPS Active' : 'Locate with GPS'}
          aria-label="Locate GPS"
        >
          <LocateFixed className={`w-4 h-4 ${isLocating ? 'animate-spin' : ''}`} />
        </button>
      </div>

      {geoError && (
        <div className="mb-3 p-2.5 rounded-xl bg-amber-50 dark:bg-amber-950/40 border border-amber-200 dark:border-amber-800/60 text-xs text-amber-700 dark:text-amber-300 flex items-center gap-2">
          <AlertCircle className="w-4 h-4 shrink-0 text-amber-500" />
          <span>{geoError}</span>
        </div>
      )}

      {/* Transit Hub Selector */}
      <div className="mb-3">
        <div className="flex items-center gap-1.5 overflow-x-auto no-scrollbar py-0.5">
          {SG_HUBS.map((hub) => (
            <button
              key={hub.name}
              onClick={() => {
                setUsingGps(false);
                loadForCoords(hub.lat, hub.lng, hub.name);
              }}
              className={`px-3 py-1.5 text-xs font-medium rounded-xl transition-colors whitespace-nowrap ${
                selectedHub === hub.name && !usingGps
                  ? 'bg-slate-900 text-white dark:bg-white dark:text-slate-900 shadow-xs'
                  : 'bg-white dark:bg-[#131b2e] text-slate-600 dark:text-slate-300 border border-slate-200/80 dark:border-slate-800 hover:bg-slate-50'
              }`}
            >
              {hub.name}
            </button>
          ))}
        </div>
      </div>

      {/* Bus Stop Cards List */}
      <div className="space-y-2.5">
        {stops.map((stop) => (
          <StopListItem
            key={stop.code}
            stop={stop}
            onSelect={onSelectStop}
          />
        ))}
      </div>
    </div>
  );
};
