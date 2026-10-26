import React from 'react';
import { BusStop } from '../types/bus';
import { getBusRouteAndSchedule, getStopServiceSchedule } from '../data/busServiceRoutes';
import { getBusStopByCode } from '../data/singaporeBusStops';
import { X, Clock, MapPin, ChevronRight, ArrowRight, RotateCw } from 'lucide-react';

interface BusRouteSheetProps {
  serviceNo: string;
  currentStopCode?: string;
  initialDirection?: 1 | 2;
  onClose: () => void;
  onSelectStop: (stop: BusStop) => void;
}

export const BusRouteSheet: React.FC<BusRouteSheetProps> = ({
  serviceNo,
  currentStopCode,
  initialDirection,
  onClose,
  onSelectStop
}) => {
  const routeInfo = getBusRouteAndSchedule(serviceNo, currentStopCode, initialDirection);

  // Determine the single active direction/wing for the current stop or selected loop wing
  const activeDirection: 1 | 2 = React.useMemo(() => {
    if (initialDirection) return initialDirection;
    if (currentStopCode && routeInfo.direction2Stops && routeInfo.direction2Stops.length > 0) {
      const idx1 = routeInfo.direction1Stops.findIndex((s) => s.code === currentStopCode);
      const idx2 = routeInfo.direction2Stops.findIndex((s) => s.code === currentStopCode);
      if (
        (idx2 !== -1 && idx1 === -1) ||
        (idx1 === routeInfo.direction1Stops.length - 1 && idx2 === 0)
      ) {
        return 2;
      }
    }
    return 1;
  }, [initialDirection, currentStopCode, routeInfo]);

  const activeStops =
    activeDirection === 1
      ? routeInfo.direction1Stops
      : routeInfo.direction2Stops || routeInfo.direction1Stops;

  const activeOrigin = routeInfo.isDualLoop
    ? routeInfo.origin
    : activeDirection === 2
    ? routeInfo.direction1Name || activeStops[0]?.name || routeInfo.destination
    : routeInfo.origin || activeStops[0]?.name;

  const activeDestination = routeInfo.isDualLoop
    ? activeDirection === 2
      ? routeInfo.direction2Name || routeInfo.destination
      : routeInfo.direction1Name
    : routeInfo.isLoop
    ? routeInfo.destination
    : activeDirection === 2
    ? routeInfo.direction2Name || activeStops[activeStops.length - 1]?.name || routeInfo.origin
    : routeInfo.direction1Name || activeStops[activeStops.length - 1]?.name || routeInfo.destination;

  const scheduleStopCode = currentStopCode || activeStops[0]?.code;
  const scheduleStop = scheduleStopCode ? getBusStopByCode(scheduleStopCode) : undefined;
  const schedule = getStopServiceSchedule(serviceNo, scheduleStopCode, activeDirection);

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-end sm:items-center justify-center p-0 sm:p-4 animate-fade-in">
      <div className="w-full max-w-lg h-[88vh] max-h-[850px] bg-white dark:bg-[#131b2e] rounded-t-3xl sm:rounded-3xl shadow-2xl border border-slate-200 dark:border-slate-800 flex flex-col overflow-hidden">
        {/* Header */}
        <div className="px-5 py-3.5 border-b border-slate-100 dark:border-slate-800/80 flex items-center justify-between bg-slate-50/70 dark:bg-[#0c1220]/70">
          <div className="flex items-center gap-3 min-w-0">
            <span className="h-9 px-3 rounded-xl bg-slate-900 text-white dark:bg-white dark:text-slate-900 font-black text-lg flex items-center justify-center tracking-tight shadow-sm shrink-0">
              {serviceNo}
            </span>
            <div className="min-w-0">
              <div className="flex items-center gap-1.5">
                <span className="text-xs font-bold text-slate-900 dark:text-slate-100">
                  {routeInfo.isLoop ? 'Loop Route & Schedule' : 'Route & Schedule'}
                </span>
              </div>
              <div className="flex items-center gap-1 text-[11px] text-slate-400 mt-0.5 font-medium">
                <span className="truncate max-w-[130px]">{activeOrigin}</span>
                {routeInfo.isLoop ? (
                  <RotateCw className="w-3 h-3 text-rose-500 shrink-0" />
                ) : (
                  <ArrowRight className="w-3 h-3 text-slate-400 shrink-0" />
                )}
                <span className="truncate max-w-[160px]">{activeDestination}</span>
              </div>
            </div>
          </div>

          <button
            onClick={onClose}
            className="w-8 h-8 rounded-full flex items-center justify-center text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors shrink-0"
            aria-label="Close route sheet"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Scrollable Body: Schedule + Route Progression */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {/* Operating Schedule Card */}
          <div className="p-3.5 rounded-2xl bg-slate-50 dark:bg-slate-900/60 border border-slate-200/80 dark:border-slate-800 space-y-2.5">
            <div className="flex items-center justify-between text-xs font-bold text-slate-800 dark:text-slate-200 gap-2">
              <span className="flex items-center gap-1.5 min-w-0">
                <Clock className="w-3.5 h-3.5 text-rose-500 shrink-0" />
                <span className="truncate">
                  Operating Hours{scheduleStop ? ` · ${scheduleStop.name} (${scheduleStop.code})` : ''}
                </span>
              </span>
            </div>

            {/* Timetable Grid */}
            <div className="grid grid-cols-3 gap-1.5 text-center text-xs">
              <div className="p-2 rounded-xl bg-white dark:bg-[#131b2e] border border-slate-200/60 dark:border-slate-800/60">
                <span className="text-[10px] font-bold text-slate-400 uppercase block mb-0.5">
                  Weekday
                </span>
                <span className="font-mono font-bold text-slate-900 dark:text-slate-100 text-[11px] block">
                  {schedule.weekday.first} - {schedule.weekday.last}
                </span>
              </div>
              <div className="p-2 rounded-xl bg-white dark:bg-[#131b2e] border border-slate-200/60 dark:border-slate-800/60">
                <span className="text-[10px] font-bold text-slate-400 uppercase block mb-0.5">
                  Saturday
                </span>
                <span className="font-mono font-bold text-slate-900 dark:text-slate-100 text-[11px] block">
                  {schedule.saturday.first} - {schedule.saturday.last}
                </span>
              </div>
              <div className="p-2 rounded-xl bg-white dark:bg-[#131b2e] border border-slate-200/60 dark:border-slate-800/60">
                <span className="text-[10px] font-bold text-slate-400 uppercase block mb-0.5">
                  Sun / PH
                </span>
                <span className="font-mono font-bold text-slate-900 dark:text-slate-100 text-[11px] block">
                  {schedule.sunday.first} - {schedule.sunday.last}
                </span>
              </div>
            </div>

            {/* Frequency Interval Chips */}
            <div className="flex items-center justify-between text-[10px] text-slate-500 dark:text-slate-400 px-1 pt-1">
              <span>Morning Peak: <strong className="text-slate-700 dark:text-slate-300">{schedule.frequency.morningPeak}</strong></span>
              <span>Off-Peak: <strong className="text-slate-700 dark:text-slate-300">{schedule.frequency.offPeak}</strong></span>
            </div>
          </div>

          {/* Sequential Route Stop Timeline */}
          <div>
            <div className="flex items-center justify-between mb-2 px-1">
              <span className="text-xs font-bold text-slate-900 dark:text-slate-100 uppercase tracking-wider">
                Route Stops ({activeStops.length})
              </span>
              <span className="text-[10px] text-slate-400">
                Tap stop to view arrivals
              </span>
            </div>

            <div className="relative pl-6 space-y-3.5 before:absolute before:left-2.5 before:top-3 before:bottom-3 before:w-0.5 before:bg-rose-500/30">
              {activeStops.map((stop, index) => {
                const isCurrent = stop.code === currentStopCode;
                const isFirst = index === 0;
                const isLast = index === activeStops.length - 1;

                return (
                  <div
                    key={`${stop.code}-${index}`}
                    onClick={() => {
                      onSelectStop(stop);
                      onClose();
                    }}
                    className={`relative p-2.5 rounded-xl transition-all cursor-pointer group ${
                      isCurrent
                        ? 'bg-slate-100 dark:bg-slate-800/70 border border-rose-400/70 dark:border-rose-500/50'
                        : 'hover:bg-slate-100/70 dark:hover:bg-slate-900/60 border border-transparent'
                    }`}
                  >
                    {/* Node Dot on Timeline */}
                    <span
                      className={`absolute -left-[19px] top-4 w-3 h-3 rounded-full border-2 transition-all ${
                        isCurrent
                          ? 'bg-rose-600 border-white ring-2 ring-rose-500/30 scale-125'
                          : isFirst || isLast
                          ? 'bg-slate-900 dark:bg-white border-white dark:border-slate-900'
                          : 'bg-white dark:bg-[#131b2e] border-rose-500 group-hover:bg-rose-500'
                      }`}
                    />

                    <div className="flex items-center justify-between gap-2">
                      <div className="min-w-0">
                        <div className="flex items-center gap-1.5">
                          <span
                            className={`text-xs font-bold truncate ${
                              isCurrent
                                ? 'text-rose-600 dark:text-rose-400'
                                : 'text-slate-900 dark:text-slate-100 group-hover:text-rose-600 dark:group-hover:text-rose-400'
                            }`}
                          >
                            {stop.name}
                          </span>
                        </div>

                        <div className="flex items-center gap-1.5 text-[11px] text-slate-400 mt-0.5">
                          <span className="font-mono font-bold text-slate-500 dark:text-slate-400 shrink-0">
                            {stop.code}
                          </span>
                          <span className="text-slate-300 dark:text-slate-600">|</span>
                          <span className="truncate">{stop.road}</span>
                          {stop.mrtNearby && (
                            <>
                              <span>·</span>
                              <span className="text-[10px] text-emerald-600 dark:text-emerald-400 font-semibold truncate flex items-center gap-0.5">
                                <MapPin className="w-2.5 h-2.5" />
                                {stop.mrtNearby}
                              </span>
                            </>
                          )}
                        </div>
                      </div>

                      <ChevronRight className="w-4 h-4 text-slate-300 dark:text-slate-600 group-hover:text-slate-600 dark:group-hover:text-slate-300 group-hover:translate-x-0.5 transition-all shrink-0" />
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
