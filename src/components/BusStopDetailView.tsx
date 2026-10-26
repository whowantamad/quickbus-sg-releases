import React, { useState, useEffect, useCallback, useRef } from 'react';
import { BusStop, BusArrivalService, ArrivalApiResponse, NextBusInfo } from '../types/bus';
import { BusArrivalCard } from './BusArrivalCard';
import { BusRouteSheet } from './BusRouteSheet';
import { ArrowLeft, Star, RefreshCw, Search } from 'lucide-react';
import {
  toggleFavorite,
  isFavorite,
  getSettings,
  getStarredServicesForStop,
  toggleStarredServiceForStop
} from '../utils/storage';
import { isDualLoopAtStop, getBusRouteAndSchedule } from '../data/busServiceRoutes';
import { calculateArrivalMinutes } from '../utils/busUtils';

interface BusStopDetailViewProps {
  stop: BusStop;
  onBack: () => void;
  onSelectService?: (serviceNo: string) => void;
  onSelectStop?: (stop: BusStop) => void;
}

const PULL_THRESHOLD = 48;

function hasServiceArrival(svc: BusArrivalService): boolean {
  return (
    calculateArrivalMinutes(svc.NextBus?.EstimatedArrival).minutes !== null ||
    calculateArrivalMinutes(svc.NextBus2?.EstimatedArrival).minutes !== null ||
    calculateArrivalMinutes(svc.NextBus3?.EstimatedArrival).minutes !== null
  );
}

// Helper to create a staggered secondary wing arrival when splitting a dual-loop service
function shiftBusEta(bus: NextBusInfo | undefined, offsetMinutes: number): NextBusInfo | undefined {
  if (!bus || !bus.EstimatedArrival) return bus;
  const ts = Date.parse(bus.EstimatedArrival);
  if (Number.isNaN(ts)) return bus;
  return {
    ...bus,
    EstimatedArrival: new Date(ts + offsetMinutes * 60 * 1000).toISOString()
  };
}

// Expand dual-loop services (e.g. 358 East Loop & 358 West Loop at Pasir Ris Int) into 2 separate rows
function expandServicesForStop(rawServices: BusArrivalService[], stopCode: string): BusArrivalService[] {
  const expandedServices: BusArrivalService[] = [];
  for (const svc of rawServices) {
    if (isDualLoopAtStop(svc.ServiceNo, stopCode)) {
      const routeInfo = getBusRouteAndSchedule(svc.ServiceNo);
      expandedServices.push({
        ...svc,
        loopWing: 1,
        loopDirectionLabel: routeInfo.direction1Name,
        routeKey: `${svc.ServiceNo}-wing-1`
      });
      expandedServices.push({
        ...svc,
        NextBus: shiftBusEta(svc.NextBus, 3),
        NextBus2: shiftBusEta(svc.NextBus2, 4),
        NextBus3: shiftBusEta(svc.NextBus3, 3),
        loopWing: 2,
        loopDirectionLabel: routeInfo.direction2Name || 'Loop 2',
        routeKey: `${svc.ServiceNo}-wing-2`
      });
    } else {
      expandedServices.push({
        ...svc,
        routeKey: svc.ServiceNo
      });
    }
  }
  return expandedServices;
}

// Build initial offline-first service list immediately from bundled/IndexedDB stop metadata
function buildOfflineServices(stop: BusStop): BusArrivalService[] {
  const baseServices: BusArrivalService[] = (stop.services || []).map((svcNo) => ({
    ServiceNo: svcNo,
    Operator: ''
  }));
  return expandServicesForStop(baseServices, stop.code);
}

export const BusStopDetailView: React.FC<BusStopDetailViewProps> = ({
  stop,
  onBack,
  onSelectService,
  onSelectStop
}) => {
  const [services, setServices] = useState<BusArrivalService[]>(() => buildOfflineServices(stop));
  const [loading, setLoading] = useState<boolean>(true);
  const [refreshing, setRefreshing] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);
  const [starred, setStarred] = useState<boolean>(isFavorite(stop.code));
  const [starredServices, setStarredServices] = useState<string[]>(() =>
    getStarredServicesForStop(stop.code)
  );
  const [serviceSearch, setServiceSearch] = useState<string>('');
  const [showTagModal, setShowTagModal] = useState<boolean>(false);
  const [customNickname, setCustomNickname] = useState<string>('');
  const [selectedTag, setSelectedTag] = useState<string>('Commute');
  const [activeRouteService, setActiveRouteService] = useState<string | null>(null);
  const [activeRouteWing, setActiveRouteWing] = useState<1 | 2 | undefined>(undefined);

  // Swipe-down pull-to-refresh state
  const scrollContainerRef = useRef<HTMLDivElement | null>(null);
  const startYRef = useRef<number | null>(null);
  const didPullRef = useRef<boolean>(false);
  const [pullDistance, setPullDistance] = useState<number>(0);

  const settings = getSettings();
  const refreshInterval = settings.autoRefreshSeconds || 30;

  // Immediately hydrate offline services when switching to a different bus stop
  useEffect(() => {
    setServices(buildOfflineServices(stop));
    setLoading(true);
    setError(null);
  }, [stop.code]);

  // Fetch live bus arrivals from backend proxy and merge into offline service list
  const fetchArrivals = useCallback(async (isSilent = false, isPull = false) => {
    if (!isSilent && !isPull) setLoading(true);
    if (isPull) setRefreshing(true);
    setError(null);

    const startTime = Date.now();

    try {
      const headers: Record<string, string> = {};
      if (settings.datamallKey) {
        headers['x-datamall-key'] = settings.datamallKey;
      }

      const res = await fetch(`/api/bus-arrival?busStopCode=${encodeURIComponent(stop.code)}`, {
        headers
      });

      if (!res.ok) {
        throw new Error(`HTTP ${res.status}`);
      }

      const data: ArrivalApiResponse = await res.json();
      if (data.success && Array.isArray(data.services)) {
        const activeMap = new Map<string, BusArrivalService>();
        data.services.forEach((s) => activeMap.set(s.ServiceNo, s));

        // Preserve the offline service order so cards never jump around when live timings arrive
        const rawServices: BusArrivalService[] = [];
        const seen = new Set<string>();

        if (Array.isArray(stop.services)) {
          stop.services.forEach((svcNo) => {
            seen.add(svcNo);
            const liveSvc = activeMap.get(svcNo);
            if (liveSvc) {
              rawServices.push(liveSvc);
            } else {
              rawServices.push({
                ServiceNo: svcNo,
                Operator: ''
              });
            }
          });
        }

        // Append any extra live services not listed in offline metadata
        data.services.forEach((liveSvc) => {
          if (!seen.has(liveSvc.ServiceNo)) {
            rawServices.push(liveSvc);
          }
        });

        if (isPull) {
          const elapsed = Date.now() - startTime;
          if (elapsed < 500) {
            await new Promise((resolve) => setTimeout(resolve, 500 - elapsed));
          }
        }

        setServices(expandServicesForStop(rawServices, stop.code));
      } else {
        throw new Error(data.message || 'Unable to load');
      }
    } catch (err: any) {
      console.error('Failed to load arrivals:', err);
      setError(err?.message || 'Error fetching timings');
    } finally {
      setLoading(false);
      setRefreshing(false);
      setPullDistance(0);
    }
  }, [stop.code, stop.services, settings.datamallKey]);

  // Initial load
  useEffect(() => {
    fetchArrivals(false);
  }, [fetchArrivals]);

  // Auto-refresh interval
  useEffect(() => {
    if (refreshInterval <= 0) return;

    const timer = setInterval(() => {
      fetchArrivals(true);
    }, refreshInterval * 1000);

    return () => clearInterval(timer);
  }, [fetchArrivals, refreshInterval]);

  // Touch & Mouse Pull-to-Refresh handlers
  const handleTouchStart = (e: React.TouchEvent) => {
    if (refreshing) return;
    if (scrollContainerRef.current && scrollContainerRef.current.scrollTop <= 5) {
      startYRef.current = e.touches[0].clientY;
      didPullRef.current = false;
    } else {
      startYRef.current = null;
    }
  };

  const handleTouchMove = (e: React.TouchEvent) => {
    if (startYRef.current === null || refreshing) return;
    const currentY = e.touches[0].clientY;
    const diff = currentY - startYRef.current;
    if (diff > 4 && scrollContainerRef.current && scrollContainerRef.current.scrollTop <= 5) {
      didPullRef.current = true;
      setPullDistance(Math.min(diff * 0.6, 88));
    } else if (diff < 0) {
      setPullDistance(0);
    }
  };

  const finishPullGesture = () => {
    if (startYRef.current === null) return;
    startYRef.current = null;
    if (pullDistance >= PULL_THRESHOLD) {
      setPullDistance(PULL_THRESHOLD);
      fetchArrivals(false, true);
    } else {
      setPullDistance(0);
    }
    setTimeout(() => {
      didPullRef.current = false;
    }, 50);
  };

  const handleMouseDown = (e: React.MouseEvent) => {
    if (refreshing || e.button !== 0) return;
    if (scrollContainerRef.current && scrollContainerRef.current.scrollTop <= 5) {
      startYRef.current = e.clientY;
      didPullRef.current = false;
    } else {
      startYRef.current = null;
    }
  };

  const handleMouseMove = (e: React.MouseEvent) => {
    if (startYRef.current === null || refreshing) return;
    const diff = e.clientY - startYRef.current;
    if (diff > 6 && scrollContainerRef.current && scrollContainerRef.current.scrollTop <= 5) {
      didPullRef.current = true;
      setPullDistance(Math.min(diff * 0.6, 88));
    } else if (diff < 0) {
      setPullDistance(0);
    }
  };

  const handleClickCapture = (e: React.MouseEvent) => {
    if (didPullRef.current) {
      e.stopPropagation();
      e.preventDefault();
      didPullRef.current = false;
    }
  };

  const handleToggleStar = () => {
    if (!starred) {
      setShowTagModal(true);
    } else {
      const nowStarred = toggleFavorite(stop.code);
      setStarred(nowStarred);
    }
  };

  const handleSaveFavoriteWithTag = () => {
    toggleFavorite(stop.code, customNickname || stop.name, selectedTag);
    setStarred(true);
    setShowTagModal(false);
  };

  useEffect(() => {
    setStarred(isFavorite(stop.code));
    setStarredServices(getStarredServicesForStop(stop.code));
  }, [stop.code]);

  const handleToggleServiceStar = (serviceKey: string, e: React.MouseEvent) => {
    e.stopPropagation();
    const updated = toggleStarredServiceForStop(stop.code, serviceKey);
    setStarredServices(updated);
  };

  // Filtered and dynamically sorted services:
  // 1. Starred/favorite services pinned at the top
  // 2. Services with live arrival times right after favorites
  // 3. Services without arrival times ("No Est. Available" / "Not In Operation") at the bottom
  const filteredServices = services
    .filter((s) => {
      if (!serviceSearch.trim()) return true;
      const q = serviceSearch.trim().toLowerCase();
      return (
        s.ServiceNo.toLowerCase().includes(q) ||
        (s.loopDirectionLabel && s.loopDirectionLabel.toLowerCase().includes(q))
      );
    })
    .sort((a, b) => {
      const keyA = a.routeKey || a.ServiceNo;
      const keyB = b.routeKey || b.ServiceNo;
      const isStarredA = starredServices.includes(keyA);
      const isStarredB = starredServices.includes(keyB);
      if (isStarredA && !isStarredB) return -1;
      if (!isStarredA && isStarredB) return 1;
      if (isStarredA && isStarredB) {
        return starredServices.indexOf(keyA) - starredServices.indexOf(keyB);
      }

      const hasArrivalA = hasServiceArrival(a);
      const hasArrivalB = hasServiceArrival(b);
      if (hasArrivalA && !hasArrivalB) return -1;
      if (!hasArrivalA && hasArrivalB) return 1;

      return 0;
    });

  const handleCardClick = (serviceNo: string, loopWing?: 1 | 2) => {
    setActiveRouteService(serviceNo);
    setActiveRouteWing(loopWing);
    if (onSelectService) {
      onSelectService(serviceNo);
    }
  };

  return (
    <div
      ref={scrollContainerRef}
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
      onTouchEnd={finishPullGesture}
      onTouchCancel={finishPullGesture}
      onMouseDown={handleMouseDown}
      onMouseMove={handleMouseMove}
      onMouseUp={finishPullGesture}
      onMouseLeave={finishPullGesture}
      onClickCapture={handleClickCapture}
      className="flex-1 flex flex-col h-full bg-slate-50/50 dark:bg-[#0c1220] overflow-y-auto overscroll-y-contain pb-20 relative"
    >
      {/* Top Header Card */}
      <div className="bg-white dark:bg-[#131b2e] border-b border-slate-100 dark:border-slate-800/80 px-4 py-3 sticky top-0 z-10 shadow-xs">
        <div className="flex items-center justify-between gap-2">
          {/* Back button */}
          <button
            onClick={onBack}
            className="w-9 h-9 rounded-full flex items-center justify-center text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
            aria-label="Back"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>

          {/* Title and Stop Code */}
          <div className="flex-1 min-w-0 px-2 text-center">
            <div className="flex items-center justify-center gap-1.5">
              <span className="font-extrabold text-sm text-slate-900 dark:text-slate-50 truncate">
                {stop.name}
              </span>
              <span className="text-xs font-mono font-bold bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 px-1.5 py-0.5 rounded">
                {stop.code}
              </span>
            </div>
            <p className="text-[11px] text-slate-400 dark:text-slate-500 truncate mt-0.5">
              {stop.road} {stop.mrtNearby ? `· ${stop.mrtNearby}` : ''}
            </p>
          </div>

          {/* Star Button */}
          <button
            onClick={handleToggleStar}
            className={`w-9 h-9 rounded-full flex items-center justify-center transition-colors ${
              starred
                ? 'text-amber-500 bg-amber-50 dark:bg-amber-950/40'
                : 'text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800'
            }`}
            aria-label="Star bus stop"
          >
            <Star className={`w-5 h-5 ${starred ? 'fill-amber-500' : ''}`} />
          </button>
        </div>
      </div>

      {/* Filter services search bar */}
      <div className="px-4 pt-3 pb-1">
        <div className="relative">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Filter bus service (e.g. 147)..."
            value={serviceSearch}
            onChange={(e) => setServiceSearch(e.target.value)}
            className="w-full h-10 pl-9 pr-3 text-xs rounded-xl bg-white dark:bg-[#131b2e] border border-slate-200/80 dark:border-slate-800 text-slate-900 dark:text-slate-100 placeholder:text-slate-400 focus:outline-hidden focus:ring-2 focus:ring-rose-500/20 focus:border-rose-500 transition-all"
          />
        </div>
      </div>

      {/* Services List Content */}
      <div className="p-4 space-y-2">
        {/* Swipe-down Pull-to-Refresh Indicator */}
        {(pullDistance > 0 || refreshing) && (
          <div
            style={{ height: refreshing ? 44 : pullDistance }}
            className="flex items-center justify-center overflow-hidden transition-all duration-150"
          >
            <div className="px-3.5 py-1.5 rounded-full bg-white dark:bg-[#131b2e] shadow-sm border border-slate-200/80 dark:border-slate-700/80 flex items-center gap-2 text-rose-600 dark:text-rose-400">
              <RefreshCw
                className={`w-3.5 h-3.5 shrink-0 ${refreshing ? 'animate-spin' : ''}`}
                style={
                  !refreshing
                    ? { transform: `rotate(${Math.min(pullDistance * 4.5, 360)}deg)` }
                    : undefined
                }
              />
              <span className="text-[11px] font-semibold text-slate-600 dark:text-slate-300 whitespace-nowrap">
                {refreshing
                  ? 'Refreshing arrivals...'
                  : pullDistance >= PULL_THRESHOLD
                    ? 'Release to refresh'
                    : 'Pull down to refresh'}
              </span>
            </div>
          </div>
        )}
        {error && services.length > 0 && (
          <div className="flex items-center justify-between px-3.5 py-2 bg-rose-50 dark:bg-rose-950/30 rounded-xl border border-rose-200/80 dark:border-rose-900/40">
            <span className="text-xs font-medium text-rose-600 dark:text-rose-400">
              Offline view · Unable to update live arrivals
            </span>
            <button
              onClick={() => fetchArrivals(false)}
              className="p-1.5 rounded-lg text-rose-600 dark:text-rose-400 hover:bg-rose-100 dark:hover:bg-rose-900/40 transition-colors"
              aria-label="Retry fetching arrivals"
            >
              <RefreshCw className="w-3.5 h-3.5" />
            </button>
          </div>
        )}

        {loading && services.length === 0 ? (
          <div className="py-16 text-center">
            <div className="w-7 h-7 border-2 border-rose-500 border-t-transparent rounded-full animate-spin mx-auto mb-2" />
          </div>
        ) : error && services.length === 0 ? (
          <div className="py-12 text-center px-4 bg-white dark:bg-[#131b2e] rounded-2xl border border-rose-200 dark:border-rose-900/40 p-6">
            <p className="text-xs font-semibold text-rose-600 dark:text-rose-400 mb-2">{error}</p>
            <button
              onClick={() => fetchArrivals(false)}
              className="w-8 h-8 rounded-full bg-rose-600 text-white inline-flex items-center justify-center hover:bg-rose-700"
              aria-label="Retry"
            >
              <RefreshCw className="w-4 h-4" />
            </button>
          </div>
        ) : filteredServices.length === 0 ? (
          <div className="py-12 text-center text-slate-400 text-xs">
            —
          </div>
        ) : (
          filteredServices.map((svc) => {
            const svcKey = svc.routeKey || svc.ServiceNo;
            return (
              <BusArrivalCard
                key={svcKey}
                service={svc}
                currentStopCode={stop.code}
                isStarred={starredServices.includes(svcKey)}
                isLoading={loading}
                onToggleStar={(e) => handleToggleServiceStar(svcKey, e)}
                onSelectService={handleCardClick}
              />
            );
          })
        )}
      </div>

      {/* Bus Route Progression & Operating Schedule Sheet */}
      {activeRouteService && (
        <BusRouteSheet
          serviceNo={activeRouteService}
          currentStopCode={stop.code}
          initialDirection={activeRouteWing}
          onClose={() => setActiveRouteService(null)}
          onSelectStop={(newStop) => {
            setActiveRouteService(null);
            if (onSelectStop) {
              onSelectStop(newStop);
            }
          }}
        />
      )}

      {/* Bookmark Tagging Modal */}
      {showTagModal && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="w-full max-w-sm bg-white dark:bg-[#151c2e] rounded-3xl p-5 shadow-xl border border-slate-200 dark:border-slate-800 space-y-4">
            <div className="flex items-center gap-2">
              <Star className="w-5 h-5 text-amber-500 fill-amber-500" />
              <h3 className="font-bold text-base text-slate-900 dark:text-slate-100">
                Star Stop
              </h3>
            </div>

            <div>
              <input
                type="text"
                placeholder={stop.name}
                value={customNickname}
                onChange={(e) => setCustomNickname(e.target.value)}
                className="w-full h-10 px-3 text-xs rounded-xl bg-slate-50 dark:bg-slate-900 border border-slate-200 dark:border-slate-800 text-slate-900 dark:text-slate-100 focus:outline-hidden focus:ring-2 focus:ring-rose-500/20"
              />
            </div>

            <div>
              <div className="flex flex-wrap gap-1.5">
                {['Commute', 'Home', 'Work', 'School', 'Gym', 'Transit'].map((tag) => (
                  <button
                    key={tag}
                    onClick={() => setSelectedTag(tag)}
                    className={`px-3 py-1.5 text-xs font-medium rounded-lg transition-colors ${
                      selectedTag === tag
                        ? 'bg-rose-600 text-white shadow-xs'
                        : 'bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700'
                    }`}
                  >
                    {tag}
                  </button>
                ))}
              </div>
            </div>

            <div className="flex items-center justify-end gap-2 pt-2 border-t border-slate-100 dark:border-slate-800">
              <button
                onClick={() => setShowTagModal(false)}
                className="px-4 py-2 text-xs font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900"
              >
                Cancel
              </button>
              <button
                onClick={handleSaveFavoriteWithTag}
                className="px-4 py-2 text-xs font-semibold bg-rose-600 text-white rounded-xl hover:bg-rose-700 shadow-sm"
              >
                Save
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
