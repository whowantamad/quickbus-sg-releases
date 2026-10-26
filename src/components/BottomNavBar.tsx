import React from 'react';
import { Star, Compass, Search, TrainFront } from 'lucide-react';

export type TabType = 'favorites' | 'nearby' | 'search' | 'mrt';

interface BottomNavBarProps {
  activeTab: TabType;
  onChangeTab: (tab: TabType) => void;
}

export const BottomNavBar: React.FC<BottomNavBarProps> = ({
  activeTab,
  onChangeTab
}) => {
  const tabs = [
    { id: 'favorites' as TabType, label: 'Starred', icon: Star },
    { id: 'nearby' as TabType, label: 'Nearby', icon: Compass },
    { id: 'search' as TabType, label: 'Search', icon: Search },
    { id: 'mrt' as TabType, label: 'MRT', icon: TrainFront }
  ];

  return (
    <nav className="fixed bottom-0 left-0 right-0 max-w-2xl mx-auto h-16 bg-white/95 dark:bg-[#0c1220]/95 backdrop-blur-md border-t border-slate-100 dark:border-slate-800/80 z-20 grid grid-cols-4 items-center px-2 select-none">
      {tabs.map((tab) => {
        const Icon = tab.icon;
        const isActive = activeTab === tab.id;

        return (
          <button
            key={tab.id}
            onClick={() => onChangeTab(tab.id)}
            className="flex flex-col items-center justify-center h-full relative group transition-colors"
            aria-label={tab.label}
          >
            <div
              className={`w-10 h-7 rounded-full flex items-center justify-center transition-all ${
                isActive
                  ? 'bg-rose-50 text-rose-600 dark:bg-rose-950/50 dark:text-rose-400'
                  : 'text-slate-400 group-hover:text-slate-600 dark:group-hover:text-slate-200'
              }`}
            >
              <Icon className={`w-4 h-4 ${isActive && tab.id === 'favorites' ? 'fill-rose-600 dark:fill-rose-400' : ''}`} />
            </div>
            <span
              className={`text-[10px] font-semibold mt-0.5 tracking-tight transition-colors ${
                isActive
                  ? 'text-rose-600 dark:text-rose-400'
                  : 'text-slate-400 dark:text-slate-500'
              }`}
            >
              {tab.label}
            </span>
          </button>
        );
      })}
    </nav>
  );
};
