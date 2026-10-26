import React, { useState, useEffect } from 'react';
import { BusStop, UserSettings, ThemeMode } from './types/bus';
import { getSettings, saveSettings, recordStopOpen } from './utils/storage';
import { TopBar } from './components/TopBar';
import { BottomNavBar, TabType } from './components/BottomNavBar';
import { FavoritesTab } from './components/FavoritesTab';
import { NearbyTab } from './components/NearbyTab';
import { SearchTab } from './components/SearchTab';
import { MrtMapTab } from './components/MrtMapTab';
import { BusStopDetailView } from './components/BusStopDetailView';
import { SettingsModal } from './components/SettingsModal';
import { initOfflineDb, syncTransitDbIfNeeded } from './utils/offlineDb';

export default function App() {
  const [settings, setSettings] = useState<UserSettings>(getSettings());
  const [activeTab, setActiveTab] = useState<TabType>('favorites');
  const [selectedStop, setSelectedStop] = useState<BusStop | null>(null);
  const [settingsOpen, setSettingsOpen] = useState<boolean>(false);

  const handleOpenStop = (stop: BusStop) => {
    recordStopOpen(stop.code);
    setSelectedStop(stop);
  };

  // Initialize bundled offline IndexedDB and silently check server for dataset deltas
  useEffect(() => {
    initOfflineDb()
      .then(() => syncTransitDbIfNeeded(true))
      .catch((err) => {
        console.error('Failed to init offline db:', err);
      });
  }, []);

  // Check if system prefers dark
  const resolveTheme = (mode: ThemeMode): boolean => {
    if (mode === 'dark') return true;
    if (mode === 'light') return false;
    return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  };

  const [isDark, setIsDark] = useState<boolean>(resolveTheme(settings.theme));

  // Sync dark class on document root
  useEffect(() => {
    const applyTheme = () => {
      const dark = resolveTheme(settings.theme);
      setIsDark(dark);
      document.documentElement.classList.toggle('dark', dark);
      document.documentElement.style.colorScheme = dark ? 'dark' : 'light';
    };

    applyTheme();

    if (settings.theme === 'system' && window.matchMedia) {
      const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
      const handler = () => applyTheme();
      mediaQuery.addEventListener('change', handler);
      return () => mediaQuery.removeEventListener('change', handler);
    }
  }, [settings.theme]);

  const handleSettingsUpdated = (newSettings: UserSettings) => {
    setSettings(newSettings);
  };

  return (
    <div className={isDark ? 'dark' : ''}>
      <div className="min-h-screen h-screen bg-slate-50 dark:bg-slate-950 text-slate-900 dark:text-slate-100 transition-colors duration-200 flex flex-col">
        <div className="w-full max-w-2xl mx-auto flex-1 flex flex-col h-full overflow-hidden bg-white dark:bg-[#0c1220] border-x border-slate-200/80 dark:border-slate-800/80 shadow-xs relative">
          {/* Top Bar */}
          <TopBar
            onOpenSettings={() => setSettingsOpen(true)}
          />

          {/* Primary View Router */}
          <main className="flex-1 overflow-hidden relative flex flex-col">
            {selectedStop ? (
              <BusStopDetailView
                stop={selectedStop}
                onBack={() => setSelectedStop(null)}
                onSelectStop={handleOpenStop}
              />
            ) : (
              <>
                {activeTab === 'favorites' && (
                  <FavoritesTab
                    onSelectStop={handleOpenStop}
                    onNavigateToNearby={() => setActiveTab('nearby')}
                  />
                )}

                {activeTab === 'nearby' && (
                  <NearbyTab
                    onSelectStop={handleOpenStop}
                  />
                )}

                {activeTab === 'search' && (
                  <SearchTab
                    onSelectStop={handleOpenStop}
                  />
                )}

                {activeTab === 'mrt' && (
                  <MrtMapTab
                    onSelectStop={handleOpenStop}
                  />
                )}

                {/* Bottom Material 3 Navigation Bar */}
                <BottomNavBar
                  activeTab={activeTab}
                  onChangeTab={(tab) => {
                    setActiveTab(tab);
                    setSelectedStop(null);
                  }}
                />
              </>
            )}
          </main>

          {/* Settings Modal */}
          <SettingsModal
            isOpen={settingsOpen}
            onClose={() => setSettingsOpen(false)}
            settings={settings}
            onSettingsUpdated={handleSettingsUpdated}
          />
        </div>
      </div>
    </div>
  );
}
