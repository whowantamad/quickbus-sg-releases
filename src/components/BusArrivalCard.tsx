import React from 'react';
import { BusArrivalService, NextBusInfo } from '../types/bus';
import { calculateArrivalMinutes, getDeckTypeDetails } from '../utils/busUtils';
import { resolveBusServiceDirection, getNoArrivalAdvisement } from '../data/busServiceRoutes';
import { Accessibility, ArrowRight, Star, ChevronRight } from 'lucide-react';

const DoubleDeckIcon: React.FC<{ className?: string }> = ({ className = 'w-2.5 h-2.5' }) => (
  <svg
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="2.4"
    strokeLinecap="round"
    strokeLinejoin="round"
    className={className}
    aria-hidden="true"
  >
    <path d="m12.83 4.5a2 2 0 0 0-1.66 0L2.6 8.4a1 1 0 0 0 0 1.83l8.58 3.9a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83Z" />
    <path d="m21.4 15.8-8.57 3.9a2 2 0 0 1-1.66 0L2.6 15.8" />
  </svg>
);

interface BusArrivalCardProps {
  service: BusArrivalService;
  currentStopCode?: string;
  isStarred?: boolean;
  isLoading?: boolean;
  onToggleStar?: (e: React.MouseEvent) => void;
  onSelectService?: (serviceNo: string, loopWing?: 1 | 2) => void;
}

interface CompactArrivalSlotProps {
  busInfo?: NextBusInfo;
  isFirst?: boolean;
}

const CompactArrivalSlotSkeleton: React.FC = () => (
  <div className="w-11 sm:w-14 h-12 rounded-xl bg-slate-100/80 dark:bg-slate-800/40 flex flex-col justify-between items-center overflow-hidden shrink-0 animate-pulse">
    <div className="w-full h-3 pt-1 px-1" />
    <div className="flex-1 flex items-center justify-center">
      <div className="w-5 h-3.5 rounded bg-slate-200/90 dark:bg-slate-700/70" />
    </div>
    <div className="w-full h-1 bg-slate-200 dark:bg-slate-800" />
  </div>
);

const CompactArrivalSlot: React.FC<CompactArrivalSlotProps> = ({ busInfo, isFirst = false }) => {
  const eta = calculateArrivalMinutes(busInfo?.EstimatedArrival);
  const deck = getDeckTypeDetails(busInfo?.Type);
  const isWab = busInfo?.Feature === 'WAB';
  const hasBus = eta.minutes !== null;

  if (!hasBus) {
    return (
      <div className="w-11 sm:w-14 h-12 rounded-xl bg-slate-100/80 dark:bg-slate-800/40 flex flex-col justify-between items-center overflow-hidden shrink-0">
        <div className="flex-1 flex items-center justify-center">
          <span className="text-xs font-semibold text-slate-300 dark:text-slate-600 tabular-nums">—</span>
        </div>
        <div className="w-full h-1 bg-slate-200 dark:bg-slate-800" />
      </div>
    );
  }

  const getBottomBarStyle = () => {
    switch (busInfo?.Load) {
      case 'SEA':
        return 'bg-emerald-500';
      case 'SDA':
        return 'bg-amber-500';
      case 'LSD':
        return 'bg-rose-500';
      default:
        return 'bg-slate-400';
    }
  };

  return (
    <div className="w-11 sm:w-14 h-12 rounded-xl bg-slate-100/80 dark:bg-slate-800/40 text-slate-900 dark:text-slate-100 flex flex-col justify-between items-center transition-all relative overflow-hidden shrink-0">
      {/* Top vehicle badges: Double Decker & Wheelchair */}
      <div className="flex items-center justify-end w-full h-3 pt-1 px-1 gap-0.5">
        {deck.isDouble && (
          <span title="Double Decker" className="text-indigo-600 dark:text-indigo-400">
            <DoubleDeckIcon className="w-2.5 h-2.5" />
          </span>
        )}
        {isWab && (
          <span title="Wheelchair Accessible" className="text-sky-600 dark:text-sky-400">
            <Accessibility className="w-2.5 h-2.5" />
          </span>
        )}
      </div>

      {/* Arrival Minutes (Unitless: e.g. Arr, 2, 14) */}
      <div className="flex items-center justify-center flex-1">
        <span
          className={`font-black tracking-tight tabular-nums leading-none ${
            isFirst ? 'text-base sm:text-lg' : 'text-sm sm:text-base'
          } ${
            eta.isArrived
              ? 'text-rose-600 dark:text-rose-400 animate-pulse'
              : 'text-slate-900 dark:text-slate-50'
          }`}
        >
          {eta.display}
        </span>
      </div>

      {/* Solid Colored Bottom Bar */}
      <div className={`w-full h-1 ${getBottomBarStyle()}`} />
    </div>
  );
};

export const BusArrivalCard: React.FC<BusArrivalCardProps> = ({
  service,
  currentStopCode,
  isStarred = false,
  isLoading = false,
  onToggleStar,
  onSelectService
}) => {
  const b1 = service.NextBus;
  const b2 = service.NextBus2;
  const b3 = service.NextBus3;

  const eta1 = calculateArrivalMinutes(b1?.EstimatedArrival);
  const eta2 = calculateArrivalMinutes(b2?.EstimatedArrival);
  const eta3 = calculateArrivalMinutes(b3?.EstimatedArrival);
  const hasNoArrivalData =
    eta1.minutes === null && eta2.minutes === null && eta3.minutes === null;
  const noArrivalAdvisement = hasNoArrivalData
    ? getNoArrivalAdvisement(service, currentStopCode)
    : null;

  // Resolve context-aware destination / loop midpoint direction
  const directionInfo = React.useMemo(
    () => resolveBusServiceDirection(service, currentStopCode),
    [service, currentStopCode]
  );

  return (
    <div
      onClick={() => onSelectService && onSelectService(service.ServiceNo, service.loopWing)}
      className="bg-white dark:bg-[#131b2e] rounded-2xl border border-slate-200/80 dark:border-slate-800/80 hover:border-slate-300 dark:hover:border-slate-700 px-3.5 py-2.5 shadow-xs transition-all cursor-pointer active:scale-[0.99] group flex items-center justify-between gap-2.5"
      title={`Bus ${service.ServiceNo} - ${directionInfo.label}`}
    >
      {/* Left Column: Bus Service Badge & Loop/Destination Stop Label */}
      <div className="flex flex-col items-start gap-1 min-w-0 flex-1">
        <span className="h-8 min-w-[48px] px-2.5 rounded-lg bg-slate-900 text-white dark:bg-white dark:text-slate-900 font-black text-sm sm:text-base flex items-center justify-center tracking-tight shadow-sm shrink-0 group-hover:bg-rose-600 group-hover:text-white dark:group-hover:bg-rose-600 dark:group-hover:text-white transition-colors">
          {service.ServiceNo}
        </span>

        {directionInfo.label && (
          <div className="flex items-center gap-1 text-slate-500 dark:text-slate-400 text-[10px] leading-tight font-medium min-w-0 w-full">
            <ArrowRight className="w-2.5 h-2.5 text-slate-400 shrink-0" />
            <span className="truncate">{directionInfo.label}</span>
          </div>
        )}
      </div>

      {/* Right Column: Arrival Slots / Status + Star & Chevron */}
      <div className="flex items-center gap-2 shrink-0">
        {isLoading && hasNoArrivalData ? (
          <div className="flex items-center gap-1.5 shrink-0" aria-label="Loading arrival times">
            <CompactArrivalSlotSkeleton />
            <CompactArrivalSlotSkeleton />
            <CompactArrivalSlotSkeleton />
          </div>
        ) : hasNoArrivalData ? (
          <div className="h-10 px-3.5 rounded-xl bg-slate-100/80 dark:bg-slate-800/40 flex items-center justify-center shrink-0">
            <span className="text-xs font-semibold text-slate-500 dark:text-slate-400 whitespace-nowrap">
              {noArrivalAdvisement}
            </span>
          </div>
        ) : (
          <div className="flex items-center gap-1.5 shrink-0">
            <CompactArrivalSlot busInfo={b1} isFirst={true} />
            <CompactArrivalSlot busInfo={b2} />
            <CompactArrivalSlot busInfo={b3} />
          </div>
        )}

        <div className="flex items-center gap-1 shrink-0">
          {onToggleStar && (
            <button
              type="button"
              onClick={onToggleStar}
              className={`p-2 rounded-full transition-colors ${
                isStarred
                  ? 'text-amber-500 bg-amber-50 dark:bg-amber-950/40'
                  : 'text-slate-300 dark:text-slate-600 hover:text-amber-500 hover:bg-slate-100 dark:hover:bg-slate-800'
              }`}
              title={isStarred ? 'Starred' : 'Add to Starred'}
              aria-label={isStarred ? 'Unstar bus service' : 'Star bus service'}
            >
              <Star className={`w-4 h-4 ${isStarred ? 'fill-amber-500' : ''}`} />
            </button>
          )}
          <ChevronRight className="w-4 h-4 text-slate-400 group-hover:translate-x-0.5 transition-transform" />
        </div>
      </div>
    </div>
  );
};
