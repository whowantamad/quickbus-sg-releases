import React, { useState, useEffect } from 'react';
import { UserSettings, ThemeMode } from '../types/bus';
import { X, RefreshCw, CheckCircle2, AlertTriangle, Trash2, Database, Sun, Moon, Monitor } from 'lucide-react';
import { saveSettings } from '../utils/storage';
import { initOfflineDb, syncTransitDbIfNeeded, getDbStats } from '../utils/offlineDb';
import { SINGAPORE_BUS_STOPS, BUNDLED_ROUTES, BUNDLED_VERSION_HASH } from '../data/singaporeBusStops';

interface SettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
  settings: UserSettings;
  onSettingsUpdated: (newSettings: UserSettings) => void;
}

export const SettingsModal: React.FC<SettingsModalProps> = ({
  isOpen,
  onClose,
  settings,
  onSettingsUpdated
}) => {
  const [refreshSec, setRefreshSec] = useState<number>(settings.autoRefreshSeconds);
  const [theme, setTheme] = useState<ThemeMode>(settings.theme);
  const [isTesting, setIsTesting] = useState<boolean>(false);

  const [dbStats, setDbStats] = useState<{ count: number; routeCount: number; versionHash: string }>({
    count: SINGAPORE_BUS_STOPS.length,
    routeCount: Object.keys(BUNDLED_ROUTES).length,
    versionHash: BUNDLED_VERSION_HASH
  });
  const [testResult, setTestResult] = useState<{
    valid?: boolean;
    message?: string;
  } | null>(null);

  useEffect(() => {
    if (isOpen) {
      setRefreshSec(settings.autoRefreshSeconds);
      setTheme(settings.theme);
      getDbStats()
        .then((stats) => {
          setDbStats({
            count: stats.count || SINGAPORE_BUS_STOPS.length,
            routeCount: stats.routeCount || Object.keys(BUNDLED_ROUTES).length,
            versionHash: stats.versionHash || BUNDLED_VERSION_HASH
          });
        })
        .catch(() => {});
    }
  }, [isOpen, settings.autoRefreshSeconds, settings.theme]);

  if (!isOpen) return null;

  const handleSelectTheme = (nextTheme: ThemeMode) => {
    setTheme(nextTheme);
    const updated = saveSettings({ theme: nextTheme });
    onSettingsUpdated(updated);
  };

  const handleSave = () => {
    const updated = saveSettings({
      autoRefreshSeconds: refreshSec,
      theme,
      showAndroidFrame: false
    });
    onSettingsUpdated(updated);
    onClose();
  };

  const handleResetFavorites = () => {
    localStorage.removeItem('quickbus_favorites');
    localStorage.removeItem('quickbus_recents');
    localStorage.removeItem('quickbus_recent_stops');
    window.location.reload();
  };

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-center justify-center p-3 sm:p-4">
      <div className="w-full max-w-md max-h-[90vh] bg-white dark:bg-[#131b2e] rounded-3xl shadow-2xl border border-slate-200 dark:border-slate-800 flex flex-col overflow-hidden">
        {/* Header */}
        <div className="px-5 py-4 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between">
          <h3 className="font-extrabold text-base text-slate-900 dark:text-slate-50">
            Settings
          </h3>
          <button
            onClick={onClose}
            className="w-8 h-8 rounded-full flex items-center justify-center text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
            aria-label="Close settings"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Body */}
        <div className="p-5 overflow-y-auto space-y-5 text-xs text-slate-600 dark:text-slate-300">
          {/* Dark / Light Mode Toggle */}
          <div className="space-y-2">
            <label className="font-bold text-slate-900 dark:text-slate-100 block">
              Theme Mode
            </label>
            <div className="grid grid-cols-3 gap-2">
              {[
                { id: 'light' as ThemeMode, label: 'Light', icon: Sun },
                { id: 'dark' as ThemeMode, label: 'Dark', icon: Moon },
                { id: 'system' as ThemeMode, label: 'Auto', icon: Monitor }
              ].map((t) => {
                const Icon = t.icon;
                return (
                  <button
                    key={t.id}
                    type="button"
                    onClick={() => handleSelectTheme(t.id)}
                    className={`py-2.5 px-3 rounded-xl text-xs font-semibold capitalize transition-colors flex items-center justify-center gap-1.5 ${
                      theme === t.id
                        ? 'bg-rose-600 text-white shadow-xs'
                        : 'bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700'
                    }`}
                  >
                    <Icon className="w-3.5 h-3.5" />
                    <span>{t.label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Auto Refresh Setting */}
          <div className="space-y-2">
            <label className="font-bold text-slate-900 dark:text-slate-100 block">
              Auto-Refresh
            </label>
            <div className="grid grid-cols-4 gap-2">
              {[
                { sec: 15, label: '15s' },
                { sec: 30, label: '30s' },
                { sec: 60, label: '60s' },
                { sec: 0, label: 'Manual' }
              ].map((item) => (
                <button
                  key={item.sec}
                  onClick={() => setRefreshSec(item.sec)}
                  className={`py-2 rounded-xl text-xs font-semibold transition-colors ${
                    refreshSec === item.sec
                      ? 'bg-slate-900 text-white dark:bg-white dark:text-slate-900 shadow-xs'
                      : 'bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 hover:bg-slate-200'
                  }`}
                >
                  {item.label}
                </button>
              ))}
            </div>
          </div>

          {/* Offline Database Section */}
          <div className="space-y-2.5 p-3 rounded-2xl bg-slate-50 dark:bg-slate-900/50 border border-slate-200 dark:border-slate-800">
            <div className="flex items-center justify-between">
              <span className="font-bold text-slate-900 dark:text-slate-100 flex items-center gap-1.5">
                <Database className="w-3.5 h-3.5 text-emerald-500" />
                <span>Offline Database</span>
              </span>
              <span className="inline-flex items-center gap-1 text-[10px] font-bold text-emerald-700 dark:text-emerald-400">
                <CheckCircle2 className="w-3.5 h-3.5" />
                <span>{dbStats.count.toLocaleString()} stops · {dbStats.routeCount} routes</span>
              </span>
            </div>

            {testResult && (
              <div
                className={`p-2.5 rounded-xl border flex items-start gap-2 ${
                  testResult.valid
                    ? 'bg-emerald-50 text-emerald-800 border-emerald-200 dark:bg-emerald-950/40 dark:text-emerald-300 dark:border-emerald-800'
                    : 'bg-amber-50 text-amber-800 border-amber-200 dark:bg-amber-950/40 dark:text-amber-300 dark:border-amber-800'
                }`}
              >
                {testResult.valid ? (
                  <CheckCircle2 className="w-4 h-4 text-emerald-500 shrink-0 mt-0.5" />
                ) : (
                  <AlertTriangle className="w-4 h-4 text-amber-500 shrink-0 mt-0.5" />
                )}
                <span>{testResult.message}</span>
              </div>
            )}

            <div className="flex items-center gap-2 pt-1">
              <button
                type="button"
                onClick={async () => {
                  setIsTesting(true);
                  try {
                    const stats = await initOfflineDb(true);
                    setDbStats({
                      count: stats.count,
                      routeCount: Object.keys(BUNDLED_ROUTES).length,
                      versionHash: stats.versionHash || BUNDLED_VERSION_HASH
                    });
                    setTestResult({
                      valid: true,
                      message: `Re-indexed ${stats.count.toLocaleString()} bundled stops.`
                    });
                  } catch (e: any) {
                    setTestResult({
                      valid: false,
                      message: 'Failed: ' + (e?.message || 'Error')
                    });
                  } finally {
                    setIsTesting(false);
                  }
                }}
                disabled={isTesting}
                className="flex-1 py-2 px-2.5 bg-white dark:bg-[#131b2e] border border-slate-200 dark:border-slate-800 hover:border-slate-300 dark:hover:border-slate-700 text-slate-700 dark:text-slate-300 font-semibold rounded-xl text-center flex items-center justify-center gap-1 transition-colors"
              >
                <RefreshCw className={`w-3 h-3 ${isTesting ? 'animate-spin' : ''}`} />
                <span>Re-index</span>
              </button>

              <button
                type="button"
                onClick={async () => {
                  setIsTesting(true);
                  try {
                    const result = await syncTransitDbIfNeeded(false);
                    setDbStats({
                      count: result.stopCount,
                      routeCount: result.routeCount,
                      versionHash: result.versionHash
                    });
                    setTestResult({
                      valid: true,
                      message: result.message
                    });
                  } catch (e: any) {
                    setTestResult({
                      valid: false,
                      message: 'Sync error: ' + (e?.message || 'Network error')
                    });
                  } finally {
                    setIsTesting(false);
                  }
                }}
                disabled={isTesting}
                className="flex-1 py-2 px-2.5 bg-emerald-600 hover:bg-emerald-700 text-white font-semibold rounded-xl text-center flex items-center justify-center gap-1 transition-colors shadow-2xs"
              >
                <Database className="w-3.5 h-3.5" />
                <span>Check Updates</span>
              </button>
            </div>
          </div>

          {/* Clear Storage */}
          <div className="pt-2 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between">
            <span className="text-slate-400 text-[11px]">Reset bookmarks</span>
            <button
              onClick={handleResetFavorites}
              className="text-rose-600 dark:text-rose-400 hover:underline flex items-center gap-1 font-semibold text-xs"
            >
              <Trash2 className="w-3.5 h-3.5" />
              <span>Reset</span>
            </button>
          </div>
        </div>

        {/* Footer */}
        <div className="p-4 bg-slate-50 dark:bg-[#101726] border-t border-slate-100 dark:border-slate-800 flex items-center justify-end gap-2">
          <button
            onClick={onClose}
            className="px-4 py-2 text-xs font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900"
          >
            Cancel
          </button>
          <button
            onClick={handleSave}
            className="px-5 py-2 text-xs font-bold bg-rose-600 text-white rounded-xl hover:bg-rose-700 shadow-sm transition-all"
          >
            Save
          </button>
        </div>
      </div>
    </div>
  );
};
