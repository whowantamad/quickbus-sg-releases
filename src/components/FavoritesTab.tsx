import React, { useState, useEffect } from 'react';
import { BusStop, FavoriteStop } from '../types/bus';
import { getFavorites, removeFavorite } from '../utils/storage';
import { getBusStopByCode } from '../data/singaporeBusStops';
import { StopListItem } from './StopListItem';
import { Bookmark, Compass } from 'lucide-react';

interface FavoritesTabProps {
  onSelectStop: (stop: BusStop) => void;
  onNavigateToNearby: () => void;
}

export const FavoritesTab: React.FC<FavoritesTabProps> = ({
  onSelectStop,
  onNavigateToNearby
}) => {
  const [favorites, setFavorites] = useState<FavoriteStop[]>([]);
  const [activeTag, setActiveTag] = useState<string>('All');

  const reload = () => {
    setFavorites(getFavorites());
  };

  useEffect(() => {
    reload();
  }, []);

  const handleDeleteStop = (stop: BusStop) => {
    removeFavorite(stop.code);
    reload();
  };

  const tags = ['All', ...Array.from(new Set(favorites.map((f) => f.tag || 'Starred')))];

  const filtered = favorites.filter((f) => {
    if (activeTag === 'All') return true;
    return (f.tag || 'Starred') === activeTag;
  });

  return (
    <div className="flex-1 flex flex-col h-full overflow-y-auto px-4 py-4 pb-20">
      {/* Title */}
      <div className="flex items-center justify-between mb-3 shrink-0">
        <div className="flex items-center gap-2">
          <h2 className="text-base font-extrabold text-slate-900 dark:text-slate-50">
            Starred
          </h2>
          <span className="text-xs font-semibold text-slate-400 tabular-nums">
            ({favorites.length})
          </span>
        </div>
      </div>

      {/* Filter Sub-Tabs (Fixed height with shrink-0 so it never compresses when All is selected) */}
      {tags.length > 2 && (
        <div className="flex items-center gap-1.5 overflow-x-auto no-scrollbar mb-3.5 py-0.5 shrink-0">
          {tags.map((tag) => (
            <button
              key={tag}
              onClick={() => setActiveTag(tag)}
              className={`h-8 px-3.5 text-xs font-semibold rounded-xl transition-colors whitespace-nowrap shrink-0 inline-flex items-center justify-center ${
                activeTag === tag
                  ? 'bg-slate-900 text-white dark:bg-white dark:text-slate-900 shadow-xs'
                  : 'bg-white dark:bg-[#131b2e] text-slate-600 dark:text-slate-300 border border-slate-200 dark:border-slate-800 hover:bg-slate-50'
              }`}
            >
              {tag}
            </button>
          ))}
        </div>
      )}

      {/* Favorites List */}
      {filtered.length === 0 ? (
        <div className="py-20 text-center flex flex-col items-center justify-center">
          <div className="w-12 h-12 rounded-2xl bg-amber-50 dark:bg-amber-950/40 text-amber-500 flex items-center justify-center mb-3">
            <Bookmark className="w-6 h-6" />
          </div>
          <button
            onClick={onNavigateToNearby}
            className="flex items-center gap-1.5 px-4 py-2 text-xs font-semibold bg-rose-600 text-white rounded-xl hover:bg-rose-700 transition-colors shadow-sm"
          >
            <Compass className="w-3.5 h-3.5" />
            <span>Nearby</span>
          </button>
        </div>
      ) : (
        <div className="space-y-2.5">
          {filtered.map((fav) => {
            const stop = getBusStopByCode(fav.code);
            if (!stop) return null;

            return (
              <div key={fav.code} className="relative">
                {fav.customName && fav.customName !== stop.name && (
                  <div className="flex items-center justify-between px-2 mb-1">
                    <span className="text-[11px] font-bold text-rose-600 dark:text-rose-400">
                      {fav.customName}
                    </span>
                    {fav.tag && (
                      <span className="text-[10px] text-slate-400 bg-slate-100 dark:bg-slate-800 px-1.5 py-0.2 rounded">
                        {fav.tag}
                      </span>
                    )}
                  </div>
                )}
                <StopListItem
                  stop={stop}
                  onSelect={onSelectStop}
                  onStarToggled={reload}
                  onDelete={handleDeleteStop}
                  confirmBeforeUnstar={true}
                />
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};
