import React, { useState, useEffect, useRef } from 'react';
import { BusStop } from '../types/bus';
import { ChevronRight, Star, MapPin, Trash2 } from 'lucide-react';
import { isFavorite, toggleFavorite } from '../utils/storage';

interface StopListItemProps {
  stop: BusStop;
  onSelect: (stop: BusStop) => void;
  onStarToggled?: () => void;
  onDelete?: (stop: BusStop) => void;
  confirmBeforeUnstar?: boolean;
  openCount?: number;
}

const SWIPE_TRIGGER_THRESHOLD = 65;

export const StopListItem: React.FC<StopListItemProps> = ({
  stop,
  onSelect,
  onStarToggled,
  onDelete,
  confirmBeforeUnstar = false,
  openCount
}) => {
  const [starred, setStarred] = useState<boolean>(() => isFavorite(stop.code));
  const [swipeX, setSwipeX] = useState<number>(0);
  const [isSwiping, setIsSwiping] = useState<boolean>(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState<boolean>(false);

  const startXRef = useRef<number | null>(null);
  const startYRef = useRef<number | null>(null);
  const didSwipeRef = useRef<boolean>(false);
  const isHorizontalLockRef = useRef<boolean | null>(null);

  useEffect(() => {
    setStarred(isFavorite(stop.code));
  }, [stop.code]);

  const canSwipeDelete = Boolean(onDelete);

  const handleStarClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (starred && confirmBeforeUnstar && onDelete) {
      setShowDeleteConfirm(true);
      return;
    }
    const nowStarred = toggleFavorite(stop.code, stop.name);
    setStarred(nowStarred);
    if (onStarToggled) onStarToggled();
  };

  // Touch swipe handlers
  const handleTouchStart = (e: React.TouchEvent) => {
    if (!canSwipeDelete) return;
    startXRef.current = e.touches[0].clientX;
    startYRef.current = e.touches[0].clientY;
    didSwipeRef.current = false;
    isHorizontalLockRef.current = null;
    setIsSwiping(true);
  };

  const handleTouchMove = (e: React.TouchEvent) => {
    if (!canSwipeDelete || startXRef.current === null || startYRef.current === null) return;
    const dx = e.touches[0].clientX - startXRef.current;
    const dy = e.touches[0].clientY - startYRef.current;

    if (isHorizontalLockRef.current === null) {
      if (Math.abs(dx) > 8 || Math.abs(dy) > 8) {
        isHorizontalLockRef.current = Math.abs(dx) > Math.abs(dy);
      }
    }

    if (isHorizontalLockRef.current) {
      didSwipeRef.current = true;
      const clamped = Math.max(-120, Math.min(120, dx));
      setSwipeX(clamped);
    }
  };

  const finishSwipe = () => {
    if (!canSwipeDelete || startXRef.current === null) return;
    startXRef.current = null;
    startYRef.current = null;
    setIsSwiping(false);

    if (Math.abs(swipeX) >= SWIPE_TRIGGER_THRESHOLD) {
      setSwipeX(swipeX < 0 ? -76 : 76);
      setShowDeleteConfirm(true);
    } else {
      setSwipeX(0);
    }

    setTimeout(() => {
      didSwipeRef.current = false;
      isHorizontalLockRef.current = null;
    }, 60);
  };

  // Mouse drag handlers for desktop swipe testing
  const handleMouseDown = (e: React.MouseEvent) => {
    if (!canSwipeDelete || e.button !== 0) return;
    startXRef.current = e.clientX;
    startYRef.current = e.clientY;
    didSwipeRef.current = false;
    isHorizontalLockRef.current = null;
    setIsSwiping(true);
  };

  const handleMouseMove = (e: React.MouseEvent) => {
    if (!canSwipeDelete || startXRef.current === null || startYRef.current === null) return;
    const dx = e.clientX - startXRef.current;
    const dy = e.clientY - startYRef.current;

    if (isHorizontalLockRef.current === null) {
      if (Math.abs(dx) > 8 || Math.abs(dy) > 8) {
        isHorizontalLockRef.current = Math.abs(dx) > Math.abs(dy);
      }
    }

    if (isHorizontalLockRef.current) {
      didSwipeRef.current = true;
      const clamped = Math.max(-120, Math.min(120, dx));
      setSwipeX(clamped);
    }
  };

  const handleCardClick = () => {
    if (didSwipeRef.current) return;
    if (swipeX !== 0) {
      setSwipeX(0);
      return;
    }
    onSelect(stop);
  };

  const handleConfirmDelete = (e: React.MouseEvent) => {
    e.stopPropagation();
    setShowDeleteConfirm(false);
    setSwipeX(0);
    if (onDelete) {
      onDelete(stop);
    }
  };

  const handleCancelDelete = (e: React.MouseEvent) => {
    e.stopPropagation();
    setShowDeleteConfirm(false);
    setSwipeX(0);
  };

  return (
    <>
      <div className="relative overflow-hidden rounded-2xl select-none">
        {/* Swipe Delete Background Action */}
        {canSwipeDelete && (
          <div
            onClick={(e) => {
              e.stopPropagation();
              setShowDeleteConfirm(true);
            }}
            className={`absolute inset-0 bg-rose-600 text-white rounded-2xl flex items-center justify-between px-5 cursor-pointer transition-opacity ${
              Math.abs(swipeX) > 4 ? 'opacity-100' : 'opacity-0 pointer-events-none'
            }`}
          >
            <div className="flex items-center gap-1.5 text-xs font-bold">
              <Trash2 className="w-4 h-4" />
              <span>Delete</span>
            </div>
            <div className="flex items-center gap-1.5 text-xs font-bold">
              <span>Delete</span>
              <Trash2 className="w-4 h-4" />
            </div>
          </div>
        )}

        {/* Foreground Stop Card */}
        <div
          onTouchStart={handleTouchStart}
          onTouchMove={handleTouchMove}
          onTouchEnd={finishSwipe}
          onTouchCancel={finishSwipe}
          onMouseDown={handleMouseDown}
          onMouseMove={handleMouseMove}
          onMouseUp={finishSwipe}
          onMouseLeave={finishSwipe}
          onClick={handleCardClick}
          style={
            swipeX !== 0
              ? { transform: `translateX(${swipeX}px)` }
              : undefined
          }
          className={`bg-white dark:bg-[#131b2e] rounded-2xl border border-slate-100 dark:border-slate-800/80 p-3.5 shadow-xs hover:border-slate-300 dark:hover:border-slate-700 cursor-pointer flex items-center justify-between gap-3 group relative ${
            isSwiping ? '' : 'transition-all duration-200 active:scale-[0.99]'
          }`}
        >
          <div className="flex-1 min-w-0">
            {/* Top: Bus Stop Name */}
            <div className="flex items-center gap-2">
              <h4 className="font-bold text-sm text-slate-900 dark:text-slate-100 truncate group-hover:text-rose-600 dark:group-hover:text-rose-400 transition-colors">
                {stop.name}
              </h4>
            </div>

            {/* Bottom: Bus Stop Code | Road Name & Transit info */}
            <div className="flex items-center gap-1.5 text-xs text-slate-500 dark:text-slate-400 mt-0.5">
              <span className="font-mono font-bold text-slate-500 dark:text-slate-400 tabular-nums shrink-0">
                {stop.code}
              </span>
              <span className="text-slate-300 dark:text-slate-600">|</span>
              <span className="truncate">{stop.road}</span>
              {stop.mrtNearby && (
                <>
                  <span className="text-slate-300 dark:text-slate-700">·</span>
                  <span className="text-[11px] font-medium text-emerald-600 dark:text-emerald-400 truncate">
                    {stop.mrtNearby}
                  </span>
                </>
              )}
              {typeof stop.distance === 'number' && (
                <>
                  <span className="text-slate-300 dark:text-slate-700">·</span>
                  <span className="text-[11px] font-medium text-slate-400 flex items-center gap-0.5 tabular-nums">
                    <MapPin className="w-2.5 h-2.5 text-rose-500" />
                    {stop.distance < 1000 ? `${stop.distance}m` : `${(stop.distance / 1000).toFixed(1)}km`}
                  </span>
                </>
              )}
            </div>

            {/* Bus services preview pill row */}
            <div className="flex items-center gap-1.5 mt-2 overflow-x-auto no-scrollbar py-0.5">
              {stop.services.slice(0, 7).map((svc) => (
                <span
                  key={svc}
                  className="text-[11px] font-bold px-1.5 py-0.5 rounded bg-slate-50 dark:bg-slate-900 text-slate-700 dark:text-slate-300 border border-slate-100 dark:border-slate-800 shrink-0"
                >
                  {svc}
                </span>
              ))}
              {stop.services.length > 7 && (
                <span className="text-[10px] text-slate-400 font-medium px-1">
                  +{stop.services.length - 7}
                </span>
              )}
            </div>
          </div>

          {/* Right Action: Star & Chevron */}
          <div className="flex items-center gap-1 shrink-0">
            <button
              type="button"
              onClick={handleStarClick}
              className={`p-2 rounded-full transition-colors ${
                starred
                  ? 'text-amber-500 bg-amber-50 dark:bg-amber-950/40'
                  : 'text-slate-300 dark:text-slate-600 hover:text-amber-500 hover:bg-slate-100 dark:hover:bg-slate-800'
              }`}
              title={starred ? 'Starred' : 'Add to Starred'}
              aria-label="Star bus stop"
            >
              <Star className={`w-4 h-4 ${starred ? 'fill-amber-500' : ''}`} />
            </button>

            <ChevronRight className="w-4 h-4 text-slate-400 group-hover:translate-x-0.5 transition-transform" />
          </div>
        </div>
      </div>

      {/* Delete Confirmation Modal */}
      {showDeleteConfirm && (
        <div
          onClick={handleCancelDelete}
          className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4 animate-fade-in"
        >
          <div
            onClick={(e) => e.stopPropagation()}
            className="w-full max-w-xs bg-white dark:bg-[#151c2e] rounded-3xl p-5 shadow-xl border border-slate-200 dark:border-slate-800 space-y-4"
          >
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-2xl bg-rose-50 dark:bg-rose-950/50 text-rose-600 dark:text-rose-400 flex items-center justify-center shrink-0">
                <Trash2 className="w-5 h-5" />
              </div>
              <div className="min-w-0">
                <h3 className="font-bold text-sm text-slate-900 dark:text-slate-100">
                  Remove Bus Stop?
                </h3>
                <p className="text-xs text-slate-500 dark:text-slate-400 truncate mt-0.5">
                  {stop.name} ({stop.code})
                </p>
              </div>
            </div>

            <p className="text-xs text-slate-600 dark:text-slate-300 leading-relaxed">
              Are you sure you want to remove <strong className="font-semibold text-slate-900 dark:text-slate-100">{stop.name}</strong> from this list?
            </p>

            <div className="flex items-center justify-end gap-2 pt-2 border-t border-slate-100 dark:border-slate-800">
              <button
                type="button"
                onClick={handleCancelDelete}
                className="px-4 py-2 text-xs font-semibold text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-colors"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleConfirmDelete}
                className="px-4 py-2 text-xs font-semibold bg-rose-600 text-white rounded-xl hover:bg-rose-700 transition-colors shadow-xs"
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
};
