import React from 'react';
import { Settings, Zap } from 'lucide-react';

interface TopBarProps {
  onOpenSettings: () => void;
}

export const TopBar: React.FC<TopBarProps> = ({
  onOpenSettings
}) => {
  return (
    <header className="h-14 px-4 flex items-center justify-between border-b border-slate-100 dark:border-slate-800/80 bg-white/95 dark:bg-[#0c1220]/95 backdrop-blur-md sticky top-0 z-20 shrink-0">
      {/* Brand Title Zone */}
      <div className="flex items-center gap-2">
        <div className="w-8 h-8 rounded-xl bg-gradient-to-tr from-rose-600 to-red-500 flex items-center justify-center text-white shadow-sm shadow-red-500/20 select-none">
          <Zap className="w-3.5 h-3.5 fill-white -mr-0.5 shrink-0" />
          <span className="font-black text-[11px] leading-none tracking-tighter translate-y-[2px]">G</span>
        </div>
        <span className="font-bold text-base tracking-tight text-slate-900 dark:text-slate-50">
          QuickBus SG
        </span>
      </div>

      {/* Action Zone */}
      <div className="flex items-center gap-1">
        {/* Settings */}
        <button
          onClick={onOpenSettings}
          className="w-9 h-9 rounded-full flex items-center justify-center text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
          title="Settings"
          aria-label="Open settings"
        >
          <Settings className="w-4 h-4" />
        </button>
      </div>
    </header>
  );
};
