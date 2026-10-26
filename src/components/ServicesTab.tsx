import React, { useState } from 'react';
import { BusStop } from '../types/bus';
import { getAllAvailableServices, SINGAPORE_BUS_STOPS } from '../data/singaporeBusStops';
import { StopListItem } from './StopListItem';
import { BusFront, ArrowLeft, Search } from 'lucide-react';

interface ServicesTabProps {
  onSelectStop: (stop: BusStop) => void;
  selectedServiceNo?: string | null;
  onClearSelectedService?: () => void;
}

export const ServicesTab: React.FC<ServicesTabProps> = ({
  onSelectStop,
  selectedServiceNo,
  onClearSelectedService
}) => {
  const [activeService, setActiveService] = useState<string | null>(selectedServiceNo || null);
  const [filterQuery, setFilterQuery] = useState<string>('');

  const allServices = getAllAvailableServices();

  const filteredServices = allServices.filter((svc) =>
    svc.toLowerCase().includes(filterQuery.trim().toLowerCase())
  );

  const stopsForActiveService = activeService
    ? SINGAPORE_BUS_STOPS.filter((stop) => stop.services.includes(activeService))
    : [];

  return (
    <div className="flex-1 flex flex-col h-full overflow-y-auto px-4 py-4 pb-20">
      {/* View: Specific Service Selected */}
      {activeService ? (
        <div>
          {/* Header */}
          <div className="flex items-center gap-2 mb-3">
            <button
              onClick={() => {
                setActiveService(null);
                if (onClearSelectedService) onClearSelectedService();
              }}
              className="w-9 h-9 rounded-full flex items-center justify-center text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
              aria-label="Back"
            >
              <ArrowLeft className="w-5 h-5" />
            </button>
            <div className="flex items-center gap-2">
              <span className="h-7 px-2.5 rounded-lg bg-slate-900 text-white dark:bg-white dark:text-slate-900 font-extrabold text-sm flex items-center justify-center">
                {activeService}
              </span>
              <span className="text-xs font-semibold text-slate-400">
                ({stopsForActiveService.length} stops)
              </span>
            </div>
          </div>

          {/* Stops List */}
          <div className="space-y-2.5">
            {stopsForActiveService.map((stop) => (
              <StopListItem
                key={stop.code}
                stop={stop}
                onSelect={onSelectStop}
              />
            ))}
          </div>
        </div>
      ) : (
        /* View: Directory of Bus Lines */
        <div>
          <div className="flex items-center gap-2 mb-3">
            <BusFront className="w-5 h-5 text-rose-500" />
            <h2 className="text-base font-extrabold text-slate-900 dark:text-slate-50">
              Bus Lines
            </h2>
          </div>

          {/* Search bus line */}
          <div className="relative mb-3">
            <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Bus number (e.g. 190, 65)..."
              value={filterQuery}
              onChange={(e) => setFilterQuery(e.target.value)}
              className="w-full h-11 pl-10 pr-4 text-xs rounded-2xl bg-white dark:bg-[#131b2e] border border-slate-200/80 dark:border-slate-800 text-slate-900 dark:text-slate-100 placeholder:text-slate-400 focus:outline-hidden focus:ring-2 focus:ring-rose-500/20 focus:border-rose-500 transition-all shadow-xs"
            />
          </div>

          {/* Grid of bus badges */}
          <div className="grid grid-cols-4 sm:grid-cols-5 gap-2 pt-1">
            {filteredServices.map((svc) => (
              <button
                key={svc}
                onClick={() => setActiveService(svc)}
                className="h-12 rounded-xl bg-white dark:bg-[#131b2e] border border-slate-200/80 dark:border-slate-800 text-slate-900 dark:text-slate-100 font-bold text-sm flex flex-col items-center justify-center hover:border-rose-500 dark:hover:border-rose-500 active:scale-95 transition-all shadow-2xs"
              >
                <span>{svc}</span>
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};
