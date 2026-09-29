import React from "react";
import {
  Users,
  Heart,
  Code2,
  GitFork,
  Star,
  ExternalLink,
  MessageSquare,
  Globe,
  Package,
  Sparkles,
  Award,
  ShieldCheck,
  ChevronRight,
  BookOpen,
} from "lucide-react";
import { BrowserOpenURL } from "../../wailsjs/runtime/runtime";
import { useI18n } from "../i18n";

interface AboutProps {
  onNavigatePage?: (page: string) => void;
}

export const About: React.FC<AboutProps> = ({ onNavigatePage }) => {
  const { t } = useI18n();

  const openUrl = (url: string) => {
    try {
      if (BrowserOpenURL) {
        BrowserOpenURL(url);
      } else {
        window.open(url, "_blank");
      }
    } catch (err) {
      window.open(url, "_blank");
    }
  };

  return (
    <div className="h-full overflow-y-auto p-6 space-y-6 stagger-settle custom-scrollbar">
      {/* Breadcrumb & Navigation Header */}
      <div className="flex items-center gap-2 text-xs text-slate-400 font-medium animate-slide-left">
        <button
          onClick={() => onNavigatePage && onNavigatePage("dashboard")}
          className="hover:text-brand-400 transition-colors cursor-pointer"
        >
          Home
        </button>
        <span>/</span>
        <span className="text-slate-200 font-bold">{t("about", "About")}</span>
      </div>

      {/* Main Banner - Matching LeviLauncher Style */}
      <div className="launcher-card p-7 rounded-2xl relative overflow-hidden border border-white/[0.08] bg-gradient-to-r from-dark-900 via-dark-850 to-dark-900 shadow-xl animate-card-pop">
        <div className="absolute top-0 right-0 w-96 h-96 bg-brand-500/10 rounded-full blur-3xl pointer-events-none -mr-20 -mt-20"></div>

        <div className="relative z-10 space-y-2">
          <div className="flex items-center gap-3">
            <div className="w-11 h-11 rounded-2xl bg-brand-500/15 border border-brand-500/30 flex items-center justify-center text-brand-400 shadow-md animate-spring-pop">
              <Sparkles size={24} />
            </div>
            <div className="animate-slide-left">
              <h1 className="text-2xl lg:text-3xl font-black tracking-tight text-white font-sans">
                {t("aboutTitle", "About LeviLauncher & Server Manager")}
              </h1>
              <p className="text-xs text-slate-400 font-medium mt-0.5">
                {t(
                  "aboutSubtitle",
                  "LeviLauncher - A Modern Minecraft Bedrock Launcher & Server Management Ecosystem",
                )}
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Row 1: Authors & Maintainers + Special Thanks */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 stagger-settle">
        {/* Authors & Maintainers Card */}
        <div className="launcher-card rounded-2xl border border-white/[0.08] p-6 space-y-5 shadow-md flex flex-col justify-between animate-settle">
          <div>
            <div className="flex items-center gap-2 text-brand-400 font-bold text-sm uppercase tracking-wider mb-4 pb-2 border-b border-white/[0.06] animate-slide-left">
              <Users size={18} />
              <span>{t("authorsMaintainers", "Authors & Maintainers")}</span>
            </div>

            {/* Main Author: yosifdheef313 */}
            <div className="p-4 rounded-xl bg-dark-950/60 border border-white/[0.06] flex items-center justify-between gap-4 glass-panel-hover">
              <div className="flex items-center gap-3.5 min-w-0">
                <div className="w-12 h-12 rounded-full overflow-hidden border-2 border-brand-500/40 bg-dark-800 shrink-0 shadow-md">
                  <img
                    src="https://avatars.githubusercontent.com/u/284087285?v=4"
                    alt="yosifdheef313"
                    className="w-full h-full object-cover"
                    onError={(e) => {
                      (e.currentTarget as HTMLElement).style.display = "none";
                    }}
                  />
                </div>
                <div className="min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    <h3
                      className="font-bold text-base text-white hover:text-brand-300 transition-colors cursor-pointer"
                      onClick={() =>
                        openUrl("https://github.com/yosifdheef313")
                      }
                    >
                      yosifdheef313
                    </h3>
                    <span className="px-2 py-0.5 rounded-full text-[10px] font-extrabold bg-brand-500/20 text-brand-400 border border-brand-500/35">
                      Author
                    </span>
                  </div>
                  <p className="text-xs text-slate-400 mt-0.5 truncate">
                    LeviLamina_Server_Manager Author
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Special Thanks Card */}
        <div
          className="launcher-card rounded-2xl border border-white/[0.08] p-6 space-y-5 shadow-md flex flex-col justify-between animate-settle"
          style={{ animationDelay: "80ms" }}
        >
          <div>
            <div className="flex items-center gap-2 text-amber-400 font-bold text-sm uppercase tracking-wider mb-2 pb-2 border-b border-white/[0.06] animate-slide-left">
              <Award size={18} />
              <span>{t("specialThanks", "Special Thanks")}</span>
            </div>
            <p className="text-xs text-slate-400 leading-relaxed mb-4">
              Special thanks to individuals and projects supporting LeviLauncher
              and the LeviLamina modding platform.
            </p>

            <div className="space-y-3">
              {/* LeviMC Card */}
              <div className="p-3.5 rounded-xl bg-dark-950/60 border border-white/[0.06] flex items-center justify-between gap-3 glass-panel-hover">
                <div className="flex items-center gap-3 min-w-0">
                  <div className="w-9 h-9 rounded-xl bg-blue-500/15 border border-blue-500/30 flex items-center justify-center text-blue-400 font-bold shrink-0">
                    ☁️
                  </div>
                  <div>
                    <h4 className="font-bold text-xs text-slate-100">LeviMC</h4>
                  </div>
                </div>
                <button
                  onClick={() => openUrl("https://github.com/LiteLDev")}
                  className="px-3 py-1.5 rounded-lg bg-dark-800 hover:bg-dark-750 text-slate-300 text-xs font-semibold border border-white/[0.06] flex items-center gap-1.5 transition-all shrink-0 shadow-sm"
                >
                  {t("about.website", "Website")} <ExternalLink size={12} />
                </button>
              </div>

              {/* Mojang BDS */}
              <div className="p-3 rounded-xl bg-dark-950/40 border border-white/[0.04] flex items-center justify-between gap-3 glass-panel-hover">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-lg bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-emerald-400 font-bold text-xs shrink-0">
                    BDS
                  </div>
                  <div>
                    <h4 className="font-bold text-xs text-slate-200">
                      Mojang Bedrock Dedicated Server
                    </h4>
                    <p className="text-[10px] text-slate-400">
                      {t(
                        "about.bdsRuntimeDesc",
                        "Official server engine runtime",
                      )}
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Row 2: Community & Official Links */}
      <div className="launcher-card rounded-2xl border border-white/[0.08] p-6 space-y-4 shadow-md animate-card-pop">
        <div className="flex items-center gap-2 text-cyan-400 font-bold text-sm uppercase tracking-wider pb-2 border-b border-white/[0.06] animate-slide-left">
          <MessageSquare size={18} />
          <span>{t("communitySupport", "Community & Official Links")}</span>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3.5 stagger-settle">
          {/* Official Discord */}
          <div
            onClick={() => openUrl("https://discord.gg/v5R5P4vRZk")}
            className="p-4 rounded-xl bg-indigo-500/10 hover:bg-indigo-500/20 border border-indigo-500/30 hover:border-indigo-500/60 cursor-pointer transition-all space-y-2 group shadow-sm animate-settle"
          >
            <div className="flex items-center justify-between">
              <div className="w-8 h-8 rounded-lg bg-indigo-500/20 flex items-center justify-center text-indigo-400 group-hover:scale-110 transition-transform">
                <MessageSquare size={16} />
              </div>
              <ExternalLink
                size={14}
                className="text-indigo-400 group-hover:translate-x-0.5 transition-transform"
              />
            </div>
            <div>
              <h4 className="font-bold text-xs text-slate-100 group-hover:text-indigo-300 transition-colors">
                Discord Community
              </h4>
              <p className="text-[10px] text-slate-400 mt-0.5">
                Join the official LeviMC & LeviLamina Discord server
              </p>
            </div>
          </div>

          {/* Official Website */}
          <div
            onClick={() => openUrl("https://levimc.org/")}
            className="p-4 rounded-xl bg-emerald-500/10 hover:bg-emerald-500/20 border border-emerald-500/30 hover:border-emerald-500/60 cursor-pointer transition-all space-y-2 group shadow-sm animate-settle"
            style={{ animationDelay: "50ms" }}
          >
            <div className="flex items-center justify-between">
              <div className="w-8 h-8 rounded-lg bg-emerald-500/20 flex items-center justify-center text-emerald-400 group-hover:scale-110 transition-transform">
                <Globe size={16} />
              </div>
              <ExternalLink
                size={14}
                className="text-emerald-400 group-hover:translate-x-0.5 transition-transform"
              />
            </div>
            <div>
              <h4 className="font-bold text-xs text-slate-100 group-hover:text-emerald-300 transition-colors">
                LeviMC Official Web
              </h4>
              <p className="text-[10px] text-slate-400 mt-0.5">
                levimc.org portal & release news
              </p>
            </div>
          </div>

          {/* Bedrinth Packages */}
          <div
            onClick={() => openUrl("https://pkg.levimc.org/")}
            className="p-4 rounded-xl bg-purple-500/10 hover:bg-purple-500/20 border border-purple-500/30 hover:border-purple-500/60 cursor-pointer transition-all space-y-2 group shadow-sm animate-settle"
            style={{ animationDelay: "100ms" }}
          >
            <div className="flex items-center justify-between">
              <div className="w-8 h-8 rounded-lg bg-purple-500/20 flex items-center justify-center text-purple-400 group-hover:scale-110 transition-transform">
                <Package size={16} />
              </div>
              <ExternalLink
                size={14}
                className="text-purple-400 group-hover:translate-x-0.5 transition-transform"
              />
            </div>
            <div>
              <h4 className="font-bold text-xs text-slate-100 group-hover:text-purple-300 transition-colors">
                Bedrinth Index
              </h4>
              <p className="text-[10px] text-slate-400 mt-0.5">
                Browse official mods & plugin repository
              </p>
            </div>
          </div>

          {/* Documentation */}
          <div
            onClick={() => openUrl("https://lamina.levimc.org/")}
            className="p-4 rounded-xl bg-amber-500/10 hover:bg-amber-500/20 border border-amber-500/30 hover:border-amber-500/60 cursor-pointer transition-all space-y-2 group shadow-sm animate-settle"
            style={{ animationDelay: "150ms" }}
          >
            <div className="flex items-center justify-between">
              <div className="w-8 h-8 rounded-lg bg-amber-500/20 flex items-center justify-center text-amber-400 group-hover:scale-110 transition-transform">
                <BookOpen size={16} />
              </div>
              <ExternalLink
                size={14}
                className="text-amber-400 group-hover:translate-x-0.5 transition-transform"
              />
            </div>
            <div>
              <h4 className="font-bold text-xs text-slate-100 group-hover:text-amber-300 transition-colors">
                Documentation
              </h4>
              <p className="text-[10px] text-slate-400 mt-0.5">
                Developer guides & API reference
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Row 3: Source Code & Open Source + Contribute */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 stagger-settle">
        {/* Source Code & Open Source Card */}
        <div className="launcher-card rounded-2xl border border-white/[0.08] p-6 space-y-4 shadow-md flex flex-col justify-between animate-settle">
          <div className="space-y-3">
            <div className="flex items-center gap-2 text-blue-400 font-bold text-sm uppercase tracking-wider pb-2 border-b border-white/[0.06] animate-slide-left">
              <Code2 size={18} />
              <span>{t("sourceCode", "Source Code & Open Source")}</span>
            </div>

            <div className="flex flex-wrap items-center gap-2.5 pt-1 animate-slide-right">
              <button
                onClick={() =>
                  openUrl(
                    "https://github.com/yosifdheef313/LeviLamina_Server_Manager",
                  )
                }
                className="px-4 py-2 rounded-xl bg-dark-800 hover:bg-dark-750 text-slate-200 border border-white/[0.08] text-xs font-bold flex items-center gap-2 transition-all shadow-sm active:scale-95"
              >
                GitHub · LeviLamina_Server_Manager <ExternalLink size={12} />
              </button>
              <button
                onClick={() =>
                  openUrl("https://github.com/LiteLDev/LeviLauncher")
                }
                className="px-4 py-2 rounded-xl bg-dark-800 hover:bg-dark-750 text-slate-200 border border-white/[0.08] text-xs font-bold flex items-center gap-2 transition-all shadow-sm active:scale-95"
              >
                GitHub · LeviLauncher <ExternalLink size={12} />
              </button>
              <button
                onClick={() => openUrl("https://github.com/LiteLDev")}
                className="px-4 py-2 rounded-xl bg-dark-800 hover:bg-dark-750 text-slate-200 border border-white/[0.08] text-xs font-bold flex items-center gap-2 transition-all shadow-sm active:scale-95"
              >
                LeviMC Organization <ExternalLink size={12} />
              </button>
              <button
                onClick={() =>
                  openUrl("https://github.com/LiteLDev/LeviLamina")
                }
                className="px-4 py-2 rounded-xl bg-dark-800 hover:bg-dark-750 text-slate-200 border border-white/[0.08] text-xs font-bold flex items-center gap-2 transition-all shadow-sm active:scale-95"
              >
                LeviLamina <ExternalLink size={12} />
              </button>
            </div>
          </div>

          <p className="text-[11px] text-slate-500 pt-3 border-t border-white/[0.06]">
            See LICENSE in the repository for license details (LGPL-3.0 / MIT).
            Open source software for the Minecraft Bedrock community.
          </p>
        </div>

        {/* Contribute Card */}
        <div
          className="launcher-card rounded-2xl border border-white/[0.08] p-6 space-y-4 shadow-md flex flex-col justify-between animate-settle"
          style={{ animationDelay: "80ms" }}
        >
          <div className="space-y-3">
            <div className="flex items-center gap-2 text-brand-400 font-bold text-sm uppercase tracking-wider pb-2 border-b border-white/[0.06] animate-slide-left">
              <GitFork size={18} />
              <span>{t("contribute", "Contribute")}</span>
            </div>

            <p className="text-xs text-slate-400 leading-relaxed">
              Contributions via Issues or Pull Requests are welcome to improve
              LeviLauncher and the Server Manager ecosystem.
            </p>

            <div className="flex flex-wrap items-center gap-2.5 pt-1 animate-slide-right">
              <button
                onClick={() =>
                  openUrl(
                    "https://github.com/yosifdheef313/LeviLamina_Server_Manager/issues",
                  )
                }
                className="px-4 py-2 rounded-xl bg-dark-800 hover:bg-dark-750 text-slate-200 border border-white/[0.08] text-xs font-bold flex items-center gap-2 transition-all shadow-sm active:scale-95"
              >
                Issue <ExternalLink size={12} />
              </button>
              <button
                onClick={() =>
                  openUrl(
                    "https://github.com/yosifdheef313/LeviLamina_Server_Manager",
                  )
                }
                className="px-4 py-2 rounded-xl bg-gradient-to-r from-brand-500 to-emerald-500 hover:from-brand-400 hover:to-emerald-400 text-slate-950 text-xs font-bold flex items-center gap-2 transition-all shadow-md shadow-brand-500/20 active:scale-95"
              >
                <Star size={13} className="fill-slate-950" />{" "}
                {t("about.starFork", "Star / Fork")}
              </button>
            </div>
          </div>

          <div className="text-[11px] text-slate-400 pt-3 border-t border-white/[0.06] flex items-center justify-between">
            <span>
              {t("version", "Version")}: <strong>v2.0.0</strong>
            </span>
            <span className="text-brand-400 font-semibold">
              {t("about.ecosystem", "LeviLamina Ecosystem")}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
};
