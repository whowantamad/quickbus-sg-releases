import React, { useState, useEffect, useCallback } from 'react';
import { BusStop } from '../types/bus';
import { StopListItem } from './StopListItem';
import { Search, X } from 'lucide-react';
import { getRecentStopRecords, removeRecentStopRecord } from '../utils/storage';
import { searchOfflineDatabase } from '../utils/offlineDb';
import { getBusStopByCode } from '../data/singaporeBusStops';

interface SearchTabProps {
  onSelectStop: (stop: BusStop) => void;
}

export const SearchTab: React.FC<SearchTabProps> = ({ onSelectStop }) => {
  const [query, setQuery] = useState<string>('');
  const [results, setResults] = useState<BusStop[]>([]);
  const [openCounts, setOpenCounts] = useState<Record<string, number>>({});

  const loadDefaultOrRecentStops = useCallback(async () => {
    const records = getRecentStopRecords();
    const countsMap: Record<string, number> = {};
    for (const rec of records) {
      countsMap[rec.code] = rec.count;
    }
    setOpenCounts(countsMap);

    if (records.length > 0) {
      const recentStops = records
        .map((rec) => getBusStopByCode(rec.code))
        .filter((stop): stop is BusStop => Boolean(stop));

      if (recentStops.length > 0) {
        setResults(recentStops);
        return;
      }
    }

    const defaultStops = await searchOfflineDatabase('', 40);
    setResults(defaultStops);
  }, []);

  useEffect(() => {
    loadDefaultOrRecentStops();
  }, [loadDefaultOrRecentStops]);

  const handleSearch = async (q: string) => {
    setQuery(q);
    if (!q.trim()) {
      await loadDefaultOrRecentStops();
      return;
    }
    const matches = await searchOfflineDatabase(q, 50);
    setResults(matches);
  };

  const handleDeleteStop = (stop: BusStop) => {
    removeRecentStopRecord(stop.code);
    setResults((prev) => prev.filter((item) => item.code !== stop.code));
  };

  return (
    <div className="flex-1 flex flex-col h-full overflow-y-auto px-4 py-4 pb-20">
      {/* Search Input Box */}
      <div className="relative mb-3 shrink-0">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input
          type="text"
          placeholder="Stop code, road, or bus (e.g. 147)..."
          value={query}
          onChange={(e) => handleSearch(e.target.value)}
          className="w-full h-11 pl-10 pr-9 text-xs rounded-2xl bg-white dark:bg-[#131b2e] border border-slate-200/80 dark:border-slate-800 text-slate-900 dark:text-slate-100 placeholder:text-slate-400 focus:outline-hidden focus:ring-2 focus:ring-rose-500/20 focus:border-rose-500 transition-all shadow-xs"
          autoFocus
        />
        {query && (
          <button
            onClick={() => handleSearch('')}
            className="w-7 h-7 rounded-full flex items-center justify-center text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 absolute right-2 top-1/2 -translate-y-1/2"
            aria-label="Clear search"
          >
            <X className="w-4 h-4" />
          </button>
        )}
      </div>

      {/* Results List */}
      <div className="space-y-2.5">
        {results.length === 0 ? (
          <div className="py-16 text-center text-slate-400 text-xs">
            —
          </div>
        ) : (
          results.map((stop) => (
            <StopListItem
              key={stop.code}
              stop={stop}
              openCount={openCounts[stop.code]}
              onSelect={onSelectStop}
              onDelete={!query.trim() ? handleDeleteStop : undefined}
            />
          ))
        )}
      </div>
    </div>
  );
};
