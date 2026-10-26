import React, { useState, useEffect } from 'react';
import { formatSingaporeTime } from '../utils/busUtils';
import { Wifi, BatteryMedium, SignalHigh } from 'lucide-react';

interface AndroidFrameProps {
  children: React.ReactNode;
  enabled: boolean;
  onToggleFrame: () => void;
}

export const AndroidFrame: React.FC<AndroidFrameProps> = ({
  children,
  enabled,
  onToggleFrame
}) => {
  const [timeStr, setTimeStr] = useState<string>(formatSingaporeTime());

  useEffect(() => {
    const timer = setInterval(() => {
      setTimeStr(formatSingaporeTime());
    }, 10000);
    return () => clearInterval(timer);
  }, []);

  if (!enabled) {
    return (
      <div className="min-h-screen bg-slate-50 dark:bg-slate-950 text-slate-900 dark:text-slate-100 transition-colors duration-200">
        <div className="max-w-2xl mx-auto min-h-screen flex flex-col shadow-sm bg-white dark:bg-[#0c1220] border-x border-slate-200/80 dark:border-slate-800/80">
          {children}
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-slate-200 dark:bg-slate-950 py-4 px-2 sm:px-4 flex flex-col items-center justify-center transition-colors duration-200">
      {/* Device Frame */}
      <div className="w-full max-w-[420px] h-[870px] max-h-[95vh] bg-black rounded-[48px] p-3 shadow-2xl ring-1 ring-white/10 flex flex-col relative overflow-hidden transition-all duration-300">
        
        {/* Device Outer Bezel & Inner Screen */}
        <div className="w-full h-full bg-white dark:bg-[#0c1220] rounded-[38px] overflow-hidden flex flex-col relative border border-slate-700/30">
          
          {/* Android Status Bar */}
          <div className="h-10 px-6 pt-1 flex items-center justify-between text-xs font-medium text-slate-800 dark:text-slate-200 bg-white/95 dark:bg-[#0c1220]/95 backdrop-blur-sm z-30 shrink-0 select-none">
            <span className="tabular-nums font-semibold tracking-tight">{timeStr}</span>
            
            {/* Center Camera Punch Hole */}
            <div className="w-3.5 h-3.5 bg-black rounded-full ring-2 ring-slate-800/20 dark:ring-white/10 -mt-0.5" />

            <div className="flex items-center gap-1.5 opacity-90">
              <SignalHigh className="w-3.5 h-3.5" />
              <Wifi className="w-3.5 h-3.5" />
              <BatteryMedium className="w-4 h-4" />
            </div>
          </div>

          {/* Screen Body */}
          <div className="flex-1 overflow-hidden flex flex-col relative">
            {children}
          </div>

          {/* Android Bottom Navigation Pill */}
          <div className="h-5 bg-white dark:bg-[#0c1220] flex items-center justify-center shrink-0 z-30 select-none pb-1">
            <div className="w-28 h-1 bg-slate-300 dark:bg-slate-700 rounded-full" />
          </div>
        </div>
      </div>
    </div>
  );
};
