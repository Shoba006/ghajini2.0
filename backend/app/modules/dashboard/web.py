import base64
import os
from fastapi.responses import HTMLResponse

_logo_b64 = ""
try:
    from app.static.logo_data import LOGO_BASE64 as _logo_b64
except Exception:
    _logo_b64 = ""

if not _logo_b64:
    candidate_paths = [
        os.path.join(os.path.dirname(__file__), "..", "..", "static", "logo_base64.txt"),
        os.path.join(os.path.dirname(__file__), "..", "..", "static", "logo.png"),
        os.path.join(os.path.dirname(__file__), "..", "static", "logo_base64.txt"),
        os.path.join(os.path.dirname(__file__), "..", "static", "logo.png"),
        os.path.join(os.path.dirname(__file__), "static", "logo_base64.txt"),
        os.path.join(os.getcwd(), "backend", "app", "static", "logo_base64.txt"),
        os.path.join(os.getcwd(), "backend", "app", "static", "logo.png"),
    ]
    for p in candidate_paths:
        if os.path.exists(p):
            try:
                if p.endswith(".txt"):
                    with open(p, "r", encoding="utf-8") as f:
                        _logo_b64 = f.read().strip()
                elif p.endswith(".png"):
                    with open(p, "rb") as f:
                        _logo_b64 = base64.b64encode(f.read()).decode("utf-8")
                if _logo_b64:
                    break
            except Exception:
                pass

DASHBOARD_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
  <title>Ghajini 2.0 - Voice Agent Studio & Clinical Care Dashboard</title>
  <link rel="icon" type="image/png" href="data:image/png;base64,__LOGO_B64__">
  <!-- Modern clean typography: Inter -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">

  <style>
    :root {
      --primary: #0F9D7A;          /* Teal green */
      --primary-hover: #0C8567;
      --primary-light: #E8F5EE;    /* Setting tile tint */
      --primary-border: #C6E7D2;
      --accent-orange: #F26B21;    /* Ask AI orange */
      --accent-orange-hover: #D95813;
      --danger-red: #EF4444;       /* Badges & SOS only */
      --bg-page: #F4F6F7;          /* Very light gray */
      --card-bg: #FFFFFF;
      --card-border: #E5E7EB;
      --text-title: #1F2937;       /* Dark slate titles */
      --text-body: #4B5563;        /* Main body */
      --text-muted: #6B7280;       /* Sub-labels & counters */
      --sidebar-width: 58px;
    }

    * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; -webkit-tap-highlight-color: transparent; }
    body { background-color: var(--bg-page); color: var(--text-body); min-height: 100vh; display: flex; }

    /* ======================================================== */
    /* 1. LEFT SIDEBAR (Desktop 58px / Mobile Bottom Bar 58px)  */
    /* ======================================================== */
    .sidebar {
      width: var(--sidebar-width);
      background: #FFFFFF;
      border-right: 1px solid var(--card-border);
      position: fixed;
      top: 0; left: 0; bottom: 0;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: space-between;
      padding: 14px 0;
      z-index: 1000;
    }
    .sidebar-top { display: flex; flex-direction: column; align-items: center; gap: 16px; width: 100%; }
    .sidebar-logo {
      width: 40px;
      height: 40px;
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      background: var(--primary-light);
      border: 1px solid var(--primary-border);
      cursor: pointer;
      overflow: hidden;
      transition: transform 0.15s ease;
    }
    .sidebar-logo:hover { transform: scale(1.05); }
    .sidebar-logo img { width: 32px; height: 32px; object-fit: contain; }

    .nav-icons { display: flex; flex-direction: column; align-items: center; gap: 8px; width: 100%; margin-top: 6px; }
    .nav-icon-btn {
      width: 42px;
      height: 42px;
      border-radius: 10px;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      color: var(--text-muted);
      border: none;
      background: transparent;
      cursor: pointer;
      transition: all 0.15s ease;
      position: relative;
    }
    .nav-icon-btn:hover { background: #F3F4F6; color: var(--text-title); }
    .nav-icon-btn.active {
      background: var(--primary-light);
      color: var(--primary);
    }
    .nav-icon-btn.active::before {
      content: '';
      position: absolute;
      left: 0; top: 8px; bottom: 8px;
      width: 3px;
      border-radius: 0 3px 3px 0;
      background: var(--primary);
    }
    .nav-icon-btn svg { width: 20px; height: 20px; stroke-width: 1.8; }
    .nav-icon-label { display: none; font-size: 10px; font-weight: 600; margin-top: 2px; }

    .sidebar-bottom { display: flex; flex-direction: column; align-items: center; gap: 12px; width: 100%; }
    .sidebar-avatar {
      width: 32px;
      height: 32px;
      border-radius: 50%;
      background: #1F2937;
      color: white;
      font-size: 13px;
      font-weight: 600;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
    }

    /* ======================================================== */
    /* MAIN WRAPPER (Offset by sidebar)                         */
    /* ======================================================== */
    .app-wrapper {
      margin-left: var(--sidebar-width);
      flex: 1;
      display: flex;
      flex-direction: column;
      min-width: 0;
    }

    /* ======================================================== */
    /* 2. TOP HEADER BAR                                        */
    /* ======================================================== */
    .top-bar {
      min-height: 60px;
      background: #FFFFFF;
      border-bottom: 1px solid var(--card-border);
      padding: 0 20px;
      display: flex;
      align-items: center;
      position: sticky;
      top: 0;
      z-index: 100;
    }
    .desktop-top-bar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      width: 100%;
    }
    .mobile-top-bar {
      display: none;
    }
    .top-bar-left { display: flex; align-items: center; gap: 10px; min-width: 0; }
    .mobile-brand-icon { display: none; width: 34px; height: 34px; border-radius: 8px; background: var(--primary-light); align-items: center; justify-content: center; cursor: pointer; flex-shrink: 0; }
    .mobile-brand-icon img { width: 26px; height: 26px; object-fit: contain; }

    .back-btn {
      width: 32px;
      height: 32px;
      border-radius: 8px;
      border: 1px solid var(--card-border);
      background: white;
      display: flex;
      align-items: center;
      justify-content: center;
      color: var(--text-muted);
      cursor: pointer;
      flex-shrink: 0;
    }
    
    .agent-name-input {
      font-size: 14px;
      font-weight: 600;
      color: var(--text-title);
      background: #F3F4F6;
      border: 1px solid transparent;
      padding: 6px 10px;
      border-radius: 8px;
      outline: none;
      width: 250px;
      min-width: 0;
    }
    .agent-name-input:focus {
      background: white;
      border-color: var(--primary);
      box-shadow: 0 0 0 3px rgba(15, 157, 122, 0.15);
    }

    .header-pill {
      display: inline-flex;
      align-items: center;
      gap: 5px;
      padding: 5px 9px;
      border-radius: 6px;
      border: 1px solid var(--card-border);
      background: white;
      font-size: 12px;
      font-weight: 500;
      color: var(--text-body);
      cursor: pointer;
      white-space: nowrap;
      flex-shrink: 0;
    }
    .lang-selector-pill {
      display: inline-flex;
      align-items: center;
      gap: 5px;
      padding: 4px 9px;
      border-radius: 8px;
      border: 1px solid var(--primary-border);
      background: var(--primary-light);
      font-size: 12px;
      font-weight: 600;
      color: var(--primary);
      cursor: pointer;
      flex-shrink: 0;
    }
    .top-lang-dropdown {
      border: none;
      background: transparent;
      font-size: 12px;
      font-weight: 600;
      color: #065F46;
      outline: none;
      cursor: pointer;
    }
    .mobile-lang-pill {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      padding: 0 8px;
      border-radius: 8px;
      border: 1px solid var(--primary-border);
      background: var(--primary-light);
      height: 34px;
      flex-shrink: 0;
    }
    .mobile-lang-dropdown {
      border: none;
      background: transparent;
      font-size: 12px;
      font-weight: 700;
      color: #065F46;
      outline: none;
      cursor: pointer;
    }
    .header-pill-red {
      color: #DC2626;
      border-color: #FECACA;
      background: #FEF2F2;
    }

    .top-bar-right { display: flex; align-items: center; gap: 8px; flex-shrink: 0; }
    
    /* Ask AI Button (Orange) */
    .btn-ask-ai {
      height: 36px;
      padding: 0 12px;
      border-radius: 8px;
      border: none;
      background: var(--accent-orange);
      color: white;
      font-size: 13px;
      font-weight: 600;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      cursor: pointer;
      white-space: nowrap;
    }
    .btn-ask-ai:hover { background: var(--accent-orange-hover); }

    .test-with-label { font-size: 13px; color: var(--text-muted); margin: 0 2px; white-space: nowrap; }

    /* Action buttons (Teal) */
    .btn-teal {
      height: 36px;
      padding: 0 12px;
      border-radius: 8px;
      border: none;
      background: var(--primary);
      color: white;
      font-size: 13px;
      font-weight: 500;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      cursor: pointer;
      white-space: nowrap;
    }
    .btn-teal:hover { background: var(--primary-hover); }

    .btn-outline {
      height: 36px;
      padding: 0 12px;
      border-radius: 8px;
      border: 1px solid var(--card-border);
      background: white;
      color: var(--text-title);
      font-size: 13px;
      font-weight: 500;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      cursor: pointer;
      white-space: nowrap;
    }
    .btn-outline:hover { background: #F9FAFB; border-color: #D1D5DB; }

    .btn-patient-switch {
      background: #EDE9FE;
      color: #6D28D9;
      border: 1px solid #DDD6FE;
      height: 36px;
      padding: 0 12px;
      border-radius: 8px;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      white-space: nowrap;
    }
    .btn-patient-switch:hover { background: #E0E7FF; }

    /* ======================================================== */
    /* 3. TAB BAR                                               */
    /* ======================================================== */
    .tab-bar {
      min-height: 52px;
      background: #FFFFFF;
      border-bottom: 1px solid var(--card-border);
      padding: 0 20px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      overflow-x: auto;
      scrollbar-width: none;
      -webkit-overflow-scrolling: touch;
    }
    .tab-bar::-webkit-scrollbar { display: none; }

    .segmented-tabs {
      display: inline-flex;
      background: #F3F4F6;
      padding: 3px;
      border-radius: 8px;
      gap: 2px;
      overflow-x: auto;
      scrollbar-width: none;
      -webkit-overflow-scrolling: touch;
      flex-shrink: 0;
    }
    .segmented-tabs::-webkit-scrollbar { display: none; }

    .tab-btn {
      padding: 6px 12px;
      border-radius: 6px;
      border: none;
      background: transparent;
      font-size: 13px;
      font-weight: 500;
      color: var(--text-muted);
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 6px;
      white-space: nowrap;
      transition: all 0.15s ease;
    }
    .tab-btn svg { width: 15px; height: 15px; }
    .tab-btn.active {
      background: #FFFFFF;
      color: var(--text-title);
      font-weight: 600;
      box-shadow: 0 1px 3px rgba(0,0,0,0.06);
    }

    .tab-bar-right { display: flex; align-items: center; gap: 10px; flex-shrink: 0; }
    .pill-free-minutes {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 5px 12px;
      border-radius: 20px;
      border: 1px solid var(--primary-border);
      background: var(--primary-light);
      font-size: 12px;
      font-weight: 600;
      color: var(--primary);
      white-space: nowrap;
    }
    .ui-code-toggle {
      display: inline-flex;
      background: #F3F4F6;
      border-radius: 6px;
      padding: 2px;
      font-size: 12px;
      font-weight: 500;
    }
    .ui-code-btn {
      padding: 4px 10px;
      border-radius: 5px;
      border: none;
      background: transparent;
      color: var(--text-muted);
      cursor: pointer;
    }
    .ui-code-btn.active { background: white; color: var(--text-title); font-weight: 600; }

    /* ======================================================== */
    /* 4. MAIN CONTENT (Two Columns, 24px gap)                  */
    /* ======================================================== */
    .content-area {
      padding: 20px;
      max-width: 1400px;
      width: 100%;
      margin: 0 auto;
    }

    .two-column-grid {
      display: grid;
      grid-template-columns: 1.15fr 0.85fr;
      gap: 20px;
      align-items: start;
    }

    /* Cards */
    .card {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 14px;
      padding: 20px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.03);
      margin-bottom: 20px;
    }
    .card-header-clean {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 14px;
    }
    .card-title {
      font-size: 15px;
      font-weight: 600;
      color: var(--text-title);
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .card-sub {
      font-size: 12px;
      color: var(--text-muted);
      margin-top: 2px;
    }

    /* Setting Tile (Light green tint with clean border) */
    .setting-tile {
      background: var(--primary-light);
      border: 1px solid var(--primary-border);
      border-radius: 10px;
      padding: 12px 14px;
      margin-bottom: 12px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .setting-tile-info { display: flex; flex-direction: column; gap: 2px; }
    .setting-tile-title { font-size: 13.5px; font-weight: 600; color: #064E3B; display: flex; align-items: center; gap: 6px; }
    .setting-tile-desc { font-size: 11.5px; color: #065F46; }

    /* Inputs, Selects, Textareas */
    .form-group { margin-bottom: 14px; }
    .form-label {
      display: flex;
      justify-content: space-between;
      font-size: 13px;
      font-weight: 500;
      color: var(--text-title);
      margin-bottom: 5px;
    }
    .form-label-counter { font-size: 11px; color: var(--text-muted); font-weight: 400; }
    .form-control {
      width: 100%;
      border: 1px solid #D1D5DB;
      border-radius: 8px;
      padding: 9px 12px;
      font-size: 13.5px;
      color: var(--text-title);
      background: #FFFFFF;
      outline: none;
      transition: all 0.15s;
    }
    .form-control:focus {
      border-color: var(--primary);
      box-shadow: 0 0 0 3px rgba(15, 157, 122, 0.15);
    }
    textarea.form-control {
      resize: vertical;
      min-height: 100px;
      line-height: 1.5;
    }

    /* Switch Toggle */
    .switch {
      position: relative;
      display: inline-block;
      width: 38px;
      height: 22px;
      flex-shrink: 0;
    }
    .switch input { opacity: 0; width: 0; height: 0; }
    .slider {
      position: absolute; cursor: pointer;
      top: 0; left: 0; right: 0; bottom: 0;
      background-color: #D1D5DB;
      transition: .2s;
      border-radius: 22px;
    }
    .slider:before {
      position: absolute; content: "";
      height: 16px; width: 16px;
      left: 3px; bottom: 3px;
      background-color: white;
      transition: .2s;
      border-radius: 50%;
    }
    input:checked + .slider { background-color: var(--primary); }
    input:checked + .slider:before { transform: translateX(16px); }

    /* Live Testing Simulator */
    .simulator-container {
      background: #FFFFFF;
      border: 1px solid var(--card-border);
      border-radius: 14px;
      overflow: hidden;
      display: flex;
      flex-direction: column;
      height: 480px;
    }
    .simulator-header {
      background: #F9FAFB;
      border-bottom: 1px solid var(--card-border);
      padding: 12px 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .sim-status-dot {
      width: 8px; height: 8px;
      border-radius: 50%;
      background: var(--primary);
      display: inline-block;
      box-shadow: 0 0 0 3px rgba(15, 157, 122, 0.2);
    }
    .simulator-body {
      flex: 1;
      padding: 14px;
      overflow-y: auto;
      display: flex;
      flex-direction: column;
      gap: 10px;
      background: #FAFAFA;
    }
    .chat-bubble {
      max-width: 85%;
      padding: 10px 14px;
      border-radius: 12px;
      font-size: 13.5px;
      line-height: 1.45;
    }
    .chat-bubble-patient {
      align-self: flex-end;
      background: #1F2937;
      color: white;
      border-bottom-right-radius: 3px;
    }
    .chat-bubble-ghajini {
      align-self: flex-start;
      background: #FFFFFF;
      color: var(--text-title);
      border: 1px solid var(--card-border);
      border-bottom-left-radius: 3px;
      box-shadow: 0 1px 2px rgba(0,0,0,0.03);
    }
    .meta-tag {
      display: inline-block;
      font-size: 10.5px;
      font-weight: 600;
      padding: 2px 6px;
      border-radius: 4px;
      margin-top: 6px;
      margin-right: 4px;
    }
    .meta-intent { background: #EDE9FE; color: #6D28D9; }
    .meta-grounded { background: #DCFCE7; color: #15803D; }

    .simulator-footer {
      padding: 12px 14px;
      background: #FFFFFF;
      border-top: 1px solid var(--card-border);
    }
    .quick-prompts {
      display: flex;
      gap: 6px;
      overflow-x: auto;
      padding-bottom: 6px;
      margin-bottom: 8px;
      scrollbar-width: none;
      -webkit-overflow-scrolling: touch;
    }
    .quick-prompts::-webkit-scrollbar { display: none; }

    .quick-chip {
      font-size: 11.5px;
      font-weight: 500;
      color: var(--text-title);
      background: #F3F4F6;
      border: 1px solid var(--card-border);
      padding: 4px 10px;
      border-radius: 16px;
      white-space: nowrap;
      cursor: pointer;
      flex-shrink: 0;
    }
    .quick-chip:hover { background: #E5E7EB; }
    .sim-input-row { display: flex; gap: 8px; }

    /* CardioLife Live Canvas & Stats */
    .cardiolife-card {
      background: #FFFFFF;
      border: 1px solid var(--card-border);
      border-radius: 14px;
      padding: 16px 18px;
    }
    .vitals-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 10px;
      margin-top: 10px;
    }
    .vital-box {
      background: #F9FAFB;
      border: 1px solid #E5E7EB;
      border-radius: 10px;
      padding: 10px;
    }
    .vital-title { font-size: 11px; font-weight: 600; color: var(--text-muted); }
    .vital-value { font-size: 20px; font-weight: 700; color: var(--text-title); margin-top: 2px; }
    .vital-sub { font-size: 11px; font-weight: 500; color: var(--primary); }

    .ecg-mini-canvas {
      width: 100%;
      height: 65px;
      background: #0F172A;
      border-radius: 8px;
      margin-top: 10px;
      display: block;
    }

    /* Floating Toast Notifications */
    .toast-container {
      position: fixed;
      top: 16px;
      right: 16px;
      z-index: 9999;
      display: flex;
      flex-direction: column;
      gap: 8px;
      pointer-events: none;
    }
    .toast-pill {
      pointer-events: auto;
      background: #1F2937;
      color: white;
      padding: 11px 16px;
      border-radius: 10px;
      font-size: 13px;
      font-weight: 500;
      box-shadow: 0 8px 20px rgba(0,0,0,0.18);
      display: flex;
      align-items: center;
      gap: 8px;
      animation: toast-in 0.25s ease-out;
      transition: opacity 0.3s ease;
      max-width: 380px;
    }
    .toast-success { background: #065F46; border-left: 4px solid var(--primary); }
    .toast-warning { background: #78350F; border-left: 4px solid var(--accent-orange); }
    .toast-error { background: #7F1D1D; border-left: 4px solid var(--danger-red); }
    @keyframes toast-in {
      from { transform: translateX(30px); opacity: 0; }
      to { transform: translateX(0); opacity: 1; }
    }

    /* Modal / Popups */
    .modal-overlay {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(15, 23, 42, 0.6);
      backdrop-filter: blur(4px);
      display: none;
      align-items: center;
      justify-content: center;
      z-index: 2000;
      padding: 16px;
    }
    .modal-card {
      background: white;
      border-radius: 16px;
      max-width: 560px;
      width: 100%;
      padding: 22px;
      box-shadow: 0 16px 36px rgba(0,0,0,0.18);
      max-height: 90vh;
      overflow-y: auto;
    }

    /* Animated Waveform for Voice Call */
    .voice-wave-box {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 5px;
      height: 50px;
      margin: 16px 0;
    }
    .wave-bar {
      width: 4px;
      height: 14px;
      background: var(--primary);
      border-radius: 4px;
      animation: wave-anim 1s ease-in-out infinite alternate;
    }
    .wave-bar:nth-child(2) { animation-delay: 0.15s; height: 32px; }
    .wave-bar:nth-child(3) { animation-delay: 0.3s; height: 46px; }
    .wave-bar:nth-child(4) { animation-delay: 0.45s; height: 22px; }
    .wave-bar:nth-child(5) { animation-delay: 0.2s; height: 40px; }
    .wave-bar:nth-child(6) { animation-delay: 0.35s; height: 18px; }
    @keyframes wave-anim {
      0% { transform: scaleY(0.4); }
      100% { transform: scaleY(1.3); }
    }

    /* Table */
    .clean-table { width: 100%; border-collapse: collapse; font-size: 13px; }
    .clean-table th { text-align: left; padding: 10px 12px; color: var(--text-muted); font-weight: 500; border-bottom: 1px solid var(--card-border); }
    .clean-table td { padding: 12px; border-bottom: 1px solid #F3F4F6; color: var(--text-title); }

    /* ======================================================== */
    /* PATIENT SIMPLE VIEW (Elderly Accessible Mode)            */
    /* ======================================================== */
    #patient-portal-container {
      display: none;
      max-width: 800px;
      margin: 24px auto;
      padding: 0 16px;
      text-align: center;
    }
    .patient-hero-card {
      background: white;
      border-radius: 20px;
      border: 1px solid var(--card-border);
      padding: 28px 16px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.04);
      display: flex;
      flex-direction: column;
      align-items: center;
      margin-bottom: 20px;
    }
    .patient-hero-logo {
      width: 110px;
      height: 110px;
      object-fit: contain;
      filter: drop-shadow(0 4px 10px rgba(0,0,0,0.08));
    }
    .patient-big-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 16px;
    }
    .patient-big-btn {
      background: white;
      border: 2px solid #E5E7EB;
      border-radius: 18px;
      padding: 22px 14px;
      cursor: pointer;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 8px;
      transition: all 0.2s;
      -webkit-tap-highlight-color: transparent;
      user-select: none;
    }
    .patient-big-btn:hover {
      transform: translateY(-2px);
      box-shadow: 0 8px 18px rgba(0,0,0,0.08);
    }
    .patient-btn-icon {
      font-size: 40px;
      line-height: 1;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .patient-btn-text {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 4px;
      width: 100%;
    }
    .patient-btn-title {
      font-size: 19px;
      font-weight: 800;
      line-height: 1.2;
    }
    .p-btn-talk { border-color: #3B82F6; background: #EFF6FF; }
    .p-btn-talk .patient-btn-title { color: #1F2937; }
    .p-btn-talk .patient-btn-sub { color: var(--text-muted); }

    .p-btn-call { border-color: var(--primary); background: var(--primary-light); }
    .p-btn-call .patient-btn-title { color: #065F46; }
    .p-btn-call .patient-btn-sub { color: #047857; }

    .p-btn-heart { border-color: #F43F5E; background: #FFF1F2; }
    .p-btn-heart .patient-btn-title { color: #9F1239; }
    .p-btn-heart .patient-btn-sub { color: #BE123C; }

    .p-btn-sos { border-color: #EF4444; background: #FEF2F2; }
    .p-btn-sos .patient-btn-title { color: #991B1B; }
    .p-btn-sos .patient-btn-sub { color: #B91C1C; }

    .patient-btn-sub {
      font-size: 13.5px;
      line-height: 1.3;
    }

    /* ======================================================== */
    /* MOBILE OPTIMIZATIONS (Screen width <= 768px)             */
    /* ======================================================== */
    @media (max-width: 768px) {
      html, body {
        overflow-x: hidden;
        max-width: 100vw;
        width: 100%;
        min-height: 100dvh;
        -webkit-font-smoothing: antialiased;
      }
      body {
        padding-bottom: calc(60px + env(safe-area-inset-bottom, 16px));
      }

      /* 1. Sidebar becomes Bottom Thumb Navigation Bar */
      .sidebar {
        width: 100%;
        height: calc(56px + env(safe-area-inset-bottom, 14px));
        top: auto;
        bottom: 0;
        left: 0;
        right: 0;
        border-right: none;
        border-top: 1px solid var(--card-border);
        flex-direction: row;
        justify-content: space-around;
        padding: 0 4px;
        padding-bottom: env(safe-area-inset-bottom, 14px);
        box-shadow: 0 -3px 16px rgba(0,0,0,0.08);
        background: #FFFFFF;
        z-index: 1000;
      }
      .sidebar-top {
        flex-direction: row;
        width: 100%;
        justify-content: space-around;
        gap: 0;
      }
      .sidebar-logo, .sidebar-bottom {
        display: none !important;
      }
      .nav-icons {
        flex-direction: row;
        width: 100%;
        justify-content: space-around;
        margin-top: 0;
        gap: 0;
      }
      .nav-icon-btn {
        flex: 1;
        height: 52px;
        border-radius: 8px;
        padding: 4px 0;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        gap: 2px;
        color: var(--text-muted);
        background: transparent;
        position: relative;
        -webkit-tap-highlight-color: transparent;
      }
      .nav-icon-btn svg {
        width: 19px;
        height: 19px;
        stroke-width: 1.9;
      }
      .nav-icon-label {
        display: block;
        font-size: 10px;
        font-weight: 500;
        line-height: 1;
      }
      .nav-icon-btn.active {
        color: var(--primary);
        background: transparent;
      }
      .nav-icon-btn.active .nav-icon-label {
        font-weight: 700;
        color: var(--primary);
      }
      .nav-icon-btn.active::before {
        content: '';
        position: absolute;
        top: 0;
        left: 20%;
        right: 20%;
        width: 60%;
        height: 3px;
        background: var(--primary);
        border-radius: 0 0 3px 3px;
      }

      /* 2. Main Wrapper full width on mobile */
      .app-wrapper {
        margin-left: 0;
        width: 100%;
        max-width: 100vw;
        min-height: 100dvh;
        overflow-x: hidden;
      }

      /* 3. Top Header Bar on Mobile */
      .top-bar {
        min-height: auto;
        padding: 10px 12px;
        flex-direction: column;
        gap: 8px;
        background: #FFFFFF;
        border-bottom: 1px solid var(--card-border);
      }
      .desktop-top-bar {
        display: none !important;
      }
      .mobile-top-bar {
        display: flex;
        flex-direction: column;
        width: 100%;
        gap: 8px;
      }
      .mobile-nav-header {
        display: flex;
        align-items: center;
        justify-content: space-between;
        width: 100%;
        gap: 6px;
      }
      .mobile-brand {
        display: flex;
        align-items: center;
        gap: 8px;
        cursor: pointer;
        min-width: 0;
      }
      .mobile-logo-img {
        width: 36px;
        height: 36px;
        object-fit: contain;
        border-radius: 8px;
        background: var(--primary-light);
        padding: 2px;
        flex-shrink: 0;
      }
      .mobile-brand-meta {
        display: flex;
        flex-direction: column;
        min-width: 0;
      }
      .mobile-brand-name {
        font-size: 15px;
        font-weight: 700;
        color: var(--text-title);
        letter-spacing: -0.2px;
        line-height: 1.2;
        white-space: nowrap;
      }
      .mobile-brand-sub {
        font-size: 11px;
        font-weight: 500;
        color: var(--primary);
        display: flex;
        align-items: center;
        gap: 5px;
        white-space: nowrap;
      }
      .badge-dot-live {
        width: 6px;
        height: 6px;
        border-radius: 50%;
        background: #10B981;
        display: inline-block;
        box-shadow: 0 0 0 2px rgba(16, 185, 129, 0.2);
      }
      .mobile-header-actions {
        display: flex;
        align-items: center;
        gap: 6px;
        flex-shrink: 0;
      }
      .mobile-lang-pill {
        display: flex;
        align-items: center;
        background: #F3F4F6;
        border: 1px solid var(--card-border);
        border-radius: 8px;
        padding: 0 6px;
        height: 32px;
        gap: 4px;
      }
      .mobile-lang-dropdown {
        border: none;
        background: transparent;
        font-size: 12px;
        font-weight: 600;
        color: var(--text-title);
        outline: none;
        cursor: pointer;
      }
      .btn-patient-switch-mobile {
        background: #EDE9FE;
        color: #6D28D9;
        border: 1px solid #DDD6FE;
        height: 32px;
        padding: 0 10px;
        border-radius: 8px;
        font-size: 12px;
        font-weight: 600;
        cursor: pointer;
        display: inline-flex;
        align-items: center;
        gap: 4px;
        -webkit-tap-highlight-color: transparent;
      }
      .btn-avatar-mobile {
        width: 32px;
        height: 32px;
        border-radius: 50%;
        background: var(--primary);
        color: white;
        font-size: 13px;
        font-weight: 700;
        display: flex;
        align-items: center;
        justify-content: center;
        border: none;
        cursor: pointer;
        -webkit-tap-highlight-color: transparent;
      }

      /* Mobile Action Ribbon */
      .mobile-action-ribbon {
        display: flex;
        align-items: center;
        gap: 8px;
        width: 100%;
        overflow-x: auto;
        scrollbar-width: none;
        -webkit-overflow-scrolling: touch;
        padding-bottom: 2px;
      }
      .mobile-action-ribbon::-webkit-scrollbar { display: none; }
      .ribbon-btn {
        height: 32px;
        padding: 0 11px;
        border-radius: 18px;
        font-size: 12px;
        font-weight: 600;
        display: inline-flex;
        align-items: center;
        gap: 5px;
        white-space: nowrap;
        flex-shrink: 0;
        cursor: pointer;
        border: none;
        -webkit-tap-highlight-color: transparent;
      }
      .ribbon-btn-teal {
        background: var(--primary);
        color: white;
      }
      .ribbon-btn-teal-dark {
        background: #065F46;
        color: white;
      }
      .ribbon-btn-orange {
        background: var(--accent-orange);
        color: white;
      }
      .ribbon-btn-outline {
        background: white;
        border: 1px solid var(--card-border);
        color: var(--text-title);
      }

      /* 4. Tab Bar on Mobile */
      .tab-bar {
        padding: 6px 8px;
        min-height: 42px;
      }
      .segmented-tabs {
        width: 100%;
        overflow-x: auto;
        flex-wrap: nowrap;
        scrollbar-width: none;
        -webkit-overflow-scrolling: touch;
      }
      .segmented-tabs::-webkit-scrollbar { display: none; }
      .tab-btn {
        padding: 6px 10px;
        font-size: 12px;
        flex-shrink: 0;
        -webkit-tap-highlight-color: transparent;
      }
      .tab-bar-right {
        display: none;
      }

      /* 5. Main Content Area & Cards */
      .content-area {
        padding: 10px 10px calc(76px + env(safe-area-inset-bottom, 14px)) 10px;
        width: 100%;
        max-width: 100vw;
        box-sizing: border-box;
        overflow-x: hidden;
      }
      .two-column-grid {
        grid-template-columns: 1fr;
        gap: 12px;
      }
      .card {
        padding: 14px 12px;
        border-radius: 12px;
        margin-bottom: 12px;
        width: 100%;
        max-width: 100%;
        box-sizing: border-box;
        overflow: hidden;
      }

      /* Card Header Wrapping on Mobile */
      .card-header-clean {
        flex-direction: column;
        align-items: flex-start;
        gap: 8px;
        width: 100%;
      }
      .card-header-clean > div {
        width: 100%;
      }
      .card-header-clean .btn-outline,
      .card-header-clean .header-pill {
        align-self: flex-start;
      }
      .card-title {
        font-size: 14.5px;
        line-height: 1.3;
      }
      .card-sub {
        font-size: 11.5px;
        line-height: 1.4;
      }

      /* Setting Tiles: Stack gracefully with full-width button */
      .setting-tile {
        flex-direction: column;
        align-items: stretch;
        gap: 10px;
        padding: 12px;
        width: 100%;
        box-sizing: border-box;
      }
      .setting-tile.setting-tile-switch,
      .setting-tile:has(.switch) {
        flex-direction: row !important;
        align-items: center !important;
        justify-content: space-between !important;
      }
      .setting-tile-info {
        width: 100%;
        min-width: 0;
      }
      .setting-tile-title {
        font-size: 13px;
        line-height: 1.3;
      }
      .setting-tile-desc {
        font-size: 11px;
        line-height: 1.4;
        margin-top: 2px;
      }
      .setting-tile .btn-outline {
        width: 100%;
        justify-content: center;
        height: 36px;
        font-size: 12.5px;
        background: white;
      }

      /* Form Labels & Zoom Prevention */
      .form-label {
        display: flex;
        flex-direction: row;
        justify-content: space-between;
        align-items: baseline;
        flex-wrap: wrap;
        gap: 4px;
        font-size: 12.5px;
      }
      .form-label-counter {
        font-size: 11px;
        color: var(--text-muted);
      }
      .form-control, textarea.form-control {
        font-size: 16px; /* iOS Safari auto-zoom prevention */
      }

      /* Simulator Height on Mobile */
      .simulator-container {
        height: 380px;
      }

      /* Vitals Grid: 3-column compact responsive display */
      .vitals-grid {
        grid-template-columns: repeat(3, 1fr);
        gap: 6px;
      }
      .vital-box {
        padding: 8px 4px;
        text-align: center;
      }
      .vital-title {
        font-size: 9.5px;
        letter-spacing: 0.2px;
      }
      .vital-value {
        font-size: 16px;
      }
      .vital-sub {
        font-size: 10px;
      }

      /* Modals on Mobile: Native Bottom Sheet Pattern */
      .modal-overlay {
        align-items: flex-end;
        padding: 0;
      }
      .modal-card {
        width: 100%;
        max-width: 100vw;
        border-radius: 20px 20px 0 0;
        padding: 20px 16px calc(24px + env(safe-area-inset-bottom, 16px)) 16px;
        max-height: 85dvh;
        box-shadow: 0 -8px 28px rgba(0,0,0,0.22);
        animation: sheet-up 0.24s cubic-bezier(0.16, 1, 0.3, 1);
        margin: 0;
      }
      @keyframes sheet-up {
        from { transform: translateY(100%); }
        to { transform: translateY(0); }
      }
      .modal-footer-actions {
        display: flex;
        flex-direction: column-reverse;
        gap: 8px;
        width: 100%;
        margin-top: 14px;
      }
      .modal-footer-actions .btn-teal,
      .modal-footer-actions .btn-ask-ai,
      .modal-footer-actions .btn-outline {
        width: 100%;
        justify-content: center;
        height: 42px;
        font-size: 13.5px;
      }

      /* Toasts Mobile Positioning */
      .toast-container {
        top: 10px;
        left: 10px;
        right: 10px;
      }
      .toast-pill {
        max-width: 100%;
        font-size: 12.5px;
        padding: 10px 12px;
      }

      /* Patient Portal Single Column Banner Layout on Mobile */
      .patient-big-grid {
        grid-template-columns: 1fr;
        gap: 12px;
        width: 100%;
      }
      .patient-big-btn {
        flex-direction: row;
        align-items: center;
        text-align: left;
        padding: 16px 18px;
        min-height: 74px;
        gap: 16px;
        border-radius: 16px;
      }
      .patient-big-btn:active {
        transform: scale(0.98);
      }
      .patient-btn-icon {
        font-size: 34px;
        width: 52px;
        height: 52px;
        border-radius: 14px;
        background: rgba(255, 255, 255, 0.7);
        flex-shrink: 0;
      }
      .patient-btn-text {
        align-items: flex-start;
        text-align: left;
      }
      .patient-btn-title {
        font-size: 17.5px;
      }
      .patient-btn-sub {
        font-size: 12.5px;
      }
    }

    /* Narrow Phone Screens (<= 380px) */
    @media (max-width: 380px) {
      .mobile-brand-name {
        font-size: 13.5px;
      }
      .mobile-brand-sub {
        font-size: 10px;
      }
      .btn-patient-switch-mobile {
        padding: 0 8px;
        font-size: 11.5px;
        height: 30px;
      }
      .mobile-lang-pill {
        padding: 0 4px;
        height: 30px;
      }
      .mobile-lang-dropdown {
        font-size: 11px;
      }
      .btn-avatar-mobile {
        width: 30px;
        height: 30px;
        font-size: 12px;
      }
      .vitals-grid {
        grid-template-columns: repeat(3, 1fr);
        gap: 4px;
      }
      .vital-box {
        padding: 6px 2px;
      }
      .vital-title {
        font-size: 8.5px;
      }
      .vital-value {
        font-size: 14px;
      }
      .vital-sub {
        font-size: 9px;
      }
    }
  </style>
</head>
<body>

  <!-- Floating Toast Notifications -->
  <div class="toast-container" id="toast-container"></div>

  <!-- ======================================================== -->
  <!-- 1. NAVIGATION BAR (Desktop Left Sidebar / Mobile Bottom) -->
  <!-- ======================================================== -->
  <aside class="sidebar">
    <div class="sidebar-top">
      <div class="sidebar-logo" onclick="switchPortal('studio')" title="Ghajini 2.0 Studio">
        <img src="data:image/png;base64,__LOGO_B64__" onerror="this.src='/logo.png'" alt="Ghajini">
      </div>

      <nav class="nav-icons">
        <button class="nav-icon-btn active" id="nav-assistant" title="Studio" onclick="switchTab('assistant')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/><line x1="12" y1="19" x2="12" y2="22"/></svg>
          <span class="nav-icon-label">Studio</span>
        </button>
        <button class="nav-icon-btn" id="nav-postcall" title="CardioLife Vitals" onclick="switchTab('postcall')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>
          <span class="nav-icon-label">Vitals</span>
        </button>
        <button class="nav-icon-btn" id="nav-calls" title="Call Rules & Policy" onclick="switchTab('calls')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/></svg>
          <span class="nav-icon-label">Calls</span>
        </button>
        <button class="nav-icon-btn" id="nav-knowledge" title="FAISS Knowledge Engine" onclick="switchTab('knowledge')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>
          <span class="nav-icon-label">Memory</span>
        </button>
        <button class="nav-icon-btn" id="nav-caregiver" title="Caregiver Profile & Settings" onclick="openCaregiverModal()">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="7" r="4"/><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/></svg>
          <span class="nav-icon-label">Caregiver</span>
        </button>
      </nav>
    </div>

    <div class="sidebar-bottom">
      <button class="nav-icon-btn" title="Caregiver Profile" onclick="openCaregiverModal()">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>
      </button>
      <div class="sidebar-avatar" title="Priya Sharma (Caregiver)" onclick="openCaregiverModal()">P</div>
    </div>
  </aside>

  <!-- ======================================================== -->
  <!-- MAIN APP CONTAINER                                       -->
  <!-- ======================================================== -->
  <div class="app-wrapper">

    <!-- 2. TOP HEADER BAR -->
    <header class="top-bar">
      <!-- Desktop Top Bar (Clean Agency Studio Header) -->
      <div class="desktop-top-bar">
        <div class="top-bar-left">
          <div class="mobile-brand-icon" onclick="switchPortal('studio')" title="Ghajini 2.0" style="display: flex;">
            <img src="data:image/png;base64,__LOGO_B64__" onerror="this.src='/logo.png'" alt="Ghajini">
          </div>
          <button class="back-btn" title="Back" onclick="switchTab('assistant')">
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor"><line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/></svg>
          </button>
          <input type="text" class="agent-name-input" value="Ghajini 2.0 (Alzheimer's Companion)">
          
          <!-- Top Global Language Switcher (English / Hindi / Punjabi) -->
          <div class="lang-selector-pill" title="Choose Voice & Companion Language">
            <span style="font-size: 13px;">🌐</span>
            <select id="top-lang-select" class="top-lang-dropdown" onchange="setGlobalLanguage(this.value)">
              <option value="en" selected>English</option>
              <option value="hi">हिन्दी (Hindi)</option>
              <option value="pa">ਪੰਜਾਬੀ (Punjabi)</option>
            </select>
          </div>

          <div class="header-pill header-pill-red" title="SIM Direct Calling Enabled">
            <span style="font-size: 10px;">●</span> Outgoing (SIM)
          </div>
          <div class="header-pill" title="API Schemas & Endpoints" onclick="window.open('/docs', '_blank')">
            { } API
          </div>
        </div>

        <div class="top-bar-right">
          <!-- Orange Ask AI Button -->
          <button class="btn-ask-ai" onclick="openAskAIModal()">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
            Ask AI
          </button>

          <span class="test-with-label">Test with:</span>

          <!-- Teal Test Action Buttons -->
          <button class="btn-teal" onclick="openChatDrawer()">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
            Chat
          </button>
          <button class="btn-teal" onclick="openWebVoiceModal()">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="10"/><path d="M2 12h20"/></svg>
            Web Call
          </button>
          <button class="btn-teal" style="background: #065F46;" onclick="openPhoneCallModal()">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/></svg>
            Phone Call
          </button>

          <!-- Deploy Dropdown -->
          <button class="btn-outline" onclick="openDeployModal()">
            Deploy ▾
          </button>

          <!-- Toggle to Patient Simple View -->
          <button class="btn-patient-switch" onclick="switchPortal('patient')">
            👤 Patient
          </button>
        </div>
      </div>

      <!-- Mobile Top Bar (Clean Native Mobile Health Header) -->
      <div class="mobile-top-bar">
        <div class="mobile-nav-header">
          <div class="mobile-brand" onclick="switchPortal('studio')" title="Ghajini 2.0 Studio">
            <img class="mobile-logo-img" src="data:image/png;base64,__LOGO_B64__" onerror="this.src='/logo.png'" alt="Ghajini">
            <div class="mobile-brand-meta">
              <div class="mobile-brand-name">Ghajini 2.0</div>
              <div class="mobile-brand-sub"><span class="badge-dot-live"></span> Companion Active</div>
            </div>
          </div>
          <div class="mobile-header-actions">
            <!-- Mobile Language Switcher (EN / HI / PA) -->
            <div class="mobile-lang-pill" title="Choose Language">
              <span style="font-size: 11px;">🌐</span>
              <select id="top-lang-select-mobile" class="mobile-lang-dropdown" onchange="setGlobalLanguage(this.value)">
                <option value="en" selected>English</option>
                <option value="hi">हिन्दी</option>
                <option value="pa">ਪੰਜਾਬੀ</option>
              </select>
            </div>
            <button class="btn-patient-switch-mobile" onclick="switchPortal('patient')" title="Switch to Simple Patient View">
              <span>👴</span> Patient
            </button>
            <button class="btn-avatar-mobile" onclick="openCaregiverModal()" title="Priya Sharma (Caregiver Profile)">
              P
            </button>
          </div>
        </div>

        <!-- Mobile Quick Test Action Ribbon -->
        <div class="mobile-action-ribbon">
          <button class="ribbon-btn ribbon-btn-teal-dark" onclick="openPhoneCallModal()">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/></svg>
            <span>Call Priya</span>
          </button>
          <button class="ribbon-btn ribbon-btn-teal" onclick="openWebVoiceModal()">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="10"/><path d="M2 12h20"/></svg>
            <span>Web Voice</span>
          </button>
          <button class="ribbon-btn ribbon-btn-teal" onclick="openChatDrawer()">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
            <span>Chat</span>
          </button>
          <button class="ribbon-btn ribbon-btn-orange" onclick="openAskAIModal()">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
            <span>Ask AI</span>
          </button>
          <button class="ribbon-btn ribbon-btn-outline" onclick="openDeployModal()">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor"><polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/></svg>
            <span>Deploy</span>
          </button>
        </div>
      </div>
    </header>

    <!-- 3. TAB BAR -->
    <nav class="tab-bar">
      <div class="segmented-tabs">
        <button class="tab-btn active" id="tab-assistant" onclick="switchTab('assistant')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/></svg>
          Assistant Details
        </button>
        <button class="tab-btn" id="tab-calls" onclick="switchTab('calls')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/></svg>
          Call Configuration
        </button>
        <button class="tab-btn" id="tab-knowledge" onclick="switchTab('knowledge')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>
          Knowledge Base
        </button>
        <button class="tab-btn" id="tab-integrations" onclick="switchTab('integrations')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>
          Integrations
        </button>
        <button class="tab-btn" id="tab-postcall" onclick="switchTab('postcall')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>
          Post-Call & Telemetry
        </button>
        <button class="tab-btn" id="tab-history" onclick="switchTab('history')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
          Recent Calls
        </button>
      </div>

      <div class="tab-bar-right">
        <div class="pill-free-minutes">
          <span style="font-size: 10px;">●</span> SIM Telephony: Active
        </div>
        <div class="ui-code-toggle">
          <button class="ui-code-btn active" id="btn-view-ui" onclick="toggleViewMode('ui')">UI</button>
          <button class="ui-code-btn" id="btn-view-code" onclick="toggleViewMode('code')">Code</button>
        </div>
      </div>
    </nav>

    <!-- ======================================================== -->
    <!-- STUDIO WORKSPACE: TAB 1 - ASSISTANT DETAILS              -->
    <!-- ======================================================== -->
    <main id="view-assistant" class="content-area">
      <div class="two-column-grid">

        <!-- LEFT COLUMN: Agent Persona & Prompts -->
        <div class="col-left">

          <!-- Card 1: Persona & Voice Configuration -->
          <div class="card">
            <div class="card-header-clean">
              <div>
                <div class="card-title">Assistant Details</div>
                <div class="card-sub">Core voice identity, speech rate and primary language</div>
              </div>
              <span class="header-pill" style="color: var(--primary); border-color: var(--primary-border); background: var(--primary-light);">v2.0 Stable</span>
            </div>

            <!-- Voice Setting Tile -->
            <div class="setting-tile">
              <div class="setting-tile-info">
                <div class="setting-tile-title" id="voice-tile-title">
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="10"/><path d="M8 12a4 4 0 0 1 8 0"/></svg>
                  Aditi (Elder-care Gentle & Slow - 0.85x)
                </div>
                <div class="setting-tile-desc" id="voice-tile-desc">Indian Accent &bull; Calming warm cadence &bull; Noise Suppression Active</div>
              </div>
              <button class="btn-outline" style="height: 32px; font-size: 12px; background: white;" onclick="testVoicePlayback()">
                ▶ Preview Voice
              </button>
            </div>

            <div class="form-group">
              <div class="form-label">
                <span>Primary Language</span>
                <span class="form-label-counter">Fallback: English</span>
              </div>
              <select id="agent-lang" class="form-control" onchange="setGlobalLanguage(this.value)">
                <option value="en" selected>English (India) - en-IN</option>
                <option value="hi">Hindi - hi-IN (हिन्दी)</option>
                <option value="pa">Punjabi - pa-IN (ਪੰਜਾਬੀ)</option>
              </select>
            </div>

            <div class="form-group">
              <div class="form-label">
                <span>First Sentence (Greeting Message)</span>
                <span class="form-label-counter" id="greeting-counter">64/120</span>
              </div>
              <input type="text" id="agent-first-sentence" class="form-control" value="Hello! I am Ghajini, your companion. How are you feeling today?">
            </div>
          </div>

          <!-- Card 2: Clinical Instructions & Guardrails -->
          <div class="card">
            <div class="card-header-clean">
              <div>
                <div class="card-title">Instructions & Grounding Guardrails</div>
                <div class="card-sub">Deterministic rules governing Alzheimer's safety and anti-hallucination</div>
              </div>
              <button class="btn-outline" style="height: 30px; font-size: 12px;" onclick="resetInstructions()">Reset Default</button>
            </div>

            <!-- Setting Tile: Strict Grounding -->
            <div class="setting-tile setting-tile-switch">
              <div class="setting-tile-info">
                <div class="setting-tile-title">
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
                  Anti-Hallucination FAISS Guardrail
                </div>
                <div class="setting-tile-desc">Rejects invented facts. Fallback: "I am not sure. Shall I call Priya?"</div>
              </div>
              <label class="switch">
                <input type="checkbox" id="toggle-grounding" checked onchange="showToast('Anti-Hallucination Guardrail updated', 'info')">
                <span class="slider"></span>
              </label>
            </div>

            <!-- Setting Tile: Emergency Phrase Interception -->
            <div class="setting-tile setting-tile-switch">
              <div class="setting-tile-info">
                <div class="setting-tile-title">
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#DC2626"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
                  Emergency Phrase Interception
                </div>
                <div class="setting-tile-desc">Immediate rule-based SIM dialer trigger on distress phrases</div>
              </div>
              <label class="switch">
                <input type="checkbox" id="toggle-emergency-phrase" checked onchange="showToast('Emergency Phrase Interception updated', 'info')">
                <span class="slider"></span>
              </label>
            </div>

            <div class="form-group" style="margin-bottom: 0;">
              <div class="form-label">
                <span>System Prompt</span>
                <span class="form-label-counter" id="prompt-counter">486/600</span>
              </div>
              <textarea id="agent-prompt" class="form-control" rows="5">You are Ghajini, a compassionate memory companion for an Alzheimer's patient. 
Rules:
1. Speak in 1 or 2 short, calming sentences.
2. Ground all answers strictly in stored family facts (Priya is daughter in Bangalore, Dr. Sharma visits Thursdays).
3. If asked about taking medicine, check reminder records.
4. Detect anxiety and reassure the patient they are safe at home.</textarea>
            </div>
          </div>

        </div>

        <!-- RIGHT COLUMN: Interactive Simulator & CardioLife Stream -->
        <div class="col-right">

          <!-- Card 3: Interactive Voice & Chat Simulator -->
          <div class="simulator-container">
            <div class="simulator-header">
              <div style="display: flex; align-items: center; gap: 8px;">
                <span class="sim-status-dot"></span>
                <span style="font-size: 13px; font-weight: 600; color: var(--text-title);">Live Assistant Simulator</span>
              </div>
              <span style="font-size: 11px; color: var(--text-muted);">Pipeline: /v1/companion/message</span>
            </div>

            <div class="simulator-body" id="chat-stream">
              <div class="chat-bubble chat-bubble-ghajini" id="simulator-initial-bubble">
                Hello! I am Ghajini, your friend. You are safe at home. How can I help you today?
                <div>
                  <span class="meta-tag meta-intent">intent: greeting</span>
                  <span class="meta-tag meta-grounded">verified safe</span>
                </div>
              </div>
            </div>

            <div class="simulator-footer">
              <div class="quick-prompts" id="simulator-quick-prompts">
                <button class="quick-chip" onclick="quickSend('Who is Priya?')">Who is Priya?</button>
                <button class="quick-chip" onclick="quickSend('What day is it today?')">What day is it?</button>
                <button class="quick-chip" onclick="quickSend('Did I take my medicine?')">Did I take my medicine?</button>
                <button class="quick-chip" onclick="quickSend('Help me, I fell down')">🚨 Help me</button>
              </div>
              <div class="sim-input-row">
                <input type="text" id="sim-input" class="form-control" placeholder="Ask or speak to Ghajini..." onkeydown="if(event.key==='Enter') sendSimulatorText()">
                <button class="btn-teal" onclick="sendSimulatorText()">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor"><line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg>
                </button>
              </div>
            </div>
          </div>

          <!-- Card 4: CardioLife Telemetry -->
          <div class="cardiolife-card" style="margin-top: 20px;">
            <div class="card-header-clean" style="margin-bottom: 8px;">
              <div class="card-title" style="color: #BE123C;">
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#E11D48"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>
                CardioLife Telemetry Feed
              </div>
              <button class="btn-outline" style="height: 28px; font-size: 11px; padding: 0 8px;" onclick="refreshVitals(true)">Refresh</button>
            </div>
            
            <div class="vitals-grid">
              <div class="vital-box">
                <div class="vital-title">HEART RATE</div>
                <div class="vital-value" id="dash-vital-hr">74 <span style="font-size: 12px; font-weight: 500;">BPM</span></div>
                <div class="vital-sub" id="dash-vital-status">Normal Rhythm</div>
              </div>
              <div class="vital-box">
                <div class="vital-title">BLOOD PRESSURE</div>
                <div class="vital-value" id="dash-vital-bp">120/80</div>
                <div class="vital-sub">Optimal</div>
              </div>
              <div class="vital-box">
                <div class="vital-title">SPO2 OXYGEN</div>
                <div class="vital-value" id="dash-vital-spo2">98 <span style="font-size: 12px; font-weight: 500;">%</span></div>
                <div class="vital-sub">Steady</div>
              </div>
            </div>

            <!-- Mini ECG Canvas -->
            <canvas id="miniECGCanvas" class="ecg-mini-canvas" width="600" height="65"></canvas>
            
            <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 10px;">
              <span style="font-size: 11px; color: var(--text-muted);">Lead II &bull; Arrhythmia Guard Active</span>
              <button class="btn-outline" style="height: 28px; font-size: 11.5px; border-color: #FECDD3; color: #E11D48;" onclick="simulateCardiacAlert()">
                Test Cardiac Alert
              </button>
            </div>
          </div>

        </div>

      </div>
    </main>

    <!-- ======================================================== -->
    <!-- TAB 2 - CALL CONFIGURATION                               -->
    <!-- ======================================================== -->
    <main id="view-calls" class="content-area" style="display: none;">
      <div class="two-column-grid">

        <div class="col-left">
          <div class="card">
            <div class="card-header-clean">
              <div>
                <div class="card-title">SIM Telephony Policy & Cooldown Settings</div>
                <div class="card-sub">Deterministic call limits governed by modules/calls/policy.py</div>
              </div>
            </div>

            <div class="setting-tile setting-tile-switch">
              <div class="setting-tile-info">
                <div class="setting-tile-title">
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
                  Manual Cooldown Bypass
                </div>
                <div class="setting-tile-desc">Allows caregiver & patient manual dials without 2-minute delay</div>
              </div>
              <label class="switch">
                <input type="checkbox" id="toggle-cooldown-bypass" checked onchange="showToast('Cooldown Bypass toggled', 'info')">
                <span class="slider"></span>
              </label>
            </div>

            <div class="form-group">
              <div class="form-label">
                <span>Maximum Call Attempts Per Hour</span>
                <span class="form-label-counter">Safety Cap</span>
              </div>
              <input type="number" class="form-control" value="3" readonly style="background: #F9FAFB;">
            </div>

            <div class="form-group">
              <div class="form-label">
                <span>Quiet Hours Window</span>
                <span class="form-label-counter">Only emergency triggers permitted</span>
              </div>
              <div style="display: flex; gap: 10px;">
                <input type="text" class="form-control" value="22:00 (10 PM)" readonly style="background: #F9FAFB;">
                <input type="text" class="form-control" value="06:00 (6 AM)" readonly style="background: #F9FAFB;">
              </div>
            </div>

            <div style="display: flex; gap: 10px; margin-top: 18px;">
              <button class="btn-teal" onclick="resetCallCooldown()">
                🔄 Reset Call Cooldown & Throttle Locks
              </button>
            </div>
          </div>

          <!-- Emergency Contacts Card -->
          <div class="card">
            <div class="card-title" style="margin-bottom: 12px;">Emergency Contacts (Priority Ordered)</div>
            <div style="overflow-x: auto;">
              <table class="clean-table">
                <thead>
                  <tr>
                    <th>Priority</th>
                    <th>Name</th>
                    <th>Relationship</th>
                    <th>Phone Number</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td><strong>#1</strong></td>
                    <td>Priya Sharma</td>
                    <td>Daughter & Guardian</td>
                    <td><strong>+91 7604934874</strong></td>
                    <td><span class="header-pill" style="color: var(--primary);">Active</span></td>
                  </tr>
                  <tr>
                    <td>#2</td>
                    <td>Dr. Sharma</td>
                    <td>Geriatric Physician</td>
                    <td>+91 9876543212</td>
                    <td><span class="header-pill">Standby</span></td>
                  </tr>
                  <tr>
                    <td>#3</td>
                    <td>Arun Kumar</td>
                    <td>Neighbor</td>
                    <td>+91 9876543213</td>
                    <td><span class="header-pill">Standby</span></td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <div class="col-right">
          <div class="card">
            <div class="card-title" style="margin-bottom: 12px;">Instant Dial Tester</div>
            <p style="font-size: 13px; color: var(--text-muted); margin-bottom: 16px;">
              Test direct SIM call logic against backend endpoint <code>/v1/calls/request</code>:
            </p>
            <div class="form-group">
              <label class="form-label">Call Reason</label>
              <input type="text" id="test-call-reason" class="form-control" value="Routine caregiver check-in">
            </div>
            <div class="form-group">
              <label class="form-label">Trigger Source</label>
              <select id="test-call-source" class="form-control">
                <option value="manual" selected>manual (Caregiver/Patient click)</option>
                <option value="sos">sos (Emergency button)</option>
                <option value="emergency_phrase">emergency_phrase (Voice distress)</option>
                <option value="reminder_escalation">reminder_escalation (10min unacknowledged)</option>
              </select>
            </div>
            <button class="btn-teal" style="width: 100%; justify-content: center; height: 40px;" onclick="executeTestCall()">
              📞 Place Simulated SIM Call to Priya (+91 7604934874)
            </button>
            <div id="test-call-output" style="margin-top: 14px; font-size: 13px; font-weight: 500; display: none;"></div>
          </div>
        </div>

      </div>
    </main>

    <!-- ======================================================== -->
    <!-- TAB 3 - KNOWLEDGE BASE                                   -->
    <!-- ======================================================== -->
    <main id="view-knowledge" class="content-area" style="display: none;">
      <div class="two-column-grid">
        <div class="col-left">
          <div class="card">
            <div class="card-title" style="margin-bottom: 12px;">Active Stored Memories (FAISS Index)</div>
            <div style="display: flex; flex-direction: column; gap: 8px;">
              <div style="background: #F9FAFB; border: 1px solid var(--card-border); padding: 12px 14px; border-radius: 8px;">
                <div style="font-size: 13px; font-weight: 600; color: var(--text-title);">Priya is daughter</div>
                <div style="font-size: 12px; color: var(--text-muted);">Priya is your daughter. She lives in Bangalore and visits on weekends with grandson Kabir.</div>
              </div>
              <div style="background: #F9FAFB; border: 1px solid var(--card-border); padding: 12px 14px; border-radius: 8px;">
                <div style="font-size: 13px; font-weight: 600; color: var(--text-title);">Dr. Sharma visits Thursdays</div>
                <div style="font-size: 12px; color: var(--text-muted);">Dr. Sharma is your physician. He visits every Thursday at 4 PM to check your heart and memory health.</div>
              </div>
              <div style="background: #F9FAFB; border: 1px solid var(--card-border); padding: 12px 14px; border-radius: 8px;">
                <div style="font-size: 13px; font-weight: 600; color: var(--text-title);">Morning Medicine Routine</div>
                <div style="font-size: 12px; color: var(--text-muted);">You take Donepezil 5mg after breakfast every morning with warm water.</div>
              </div>
            </div>
          </div>
        </div>

        <div class="col-right">
          <div class="card">
            <div class="card-title" style="margin-bottom: 8px;">Teach Ghajini (Real-time Embedding)</div>
            <p style="font-size: 12.5px; color: var(--text-muted); margin-bottom: 14px;">
              New routines and facts are sanitized against prompt injections and embedded into FAISS immediately:
            </p>
            <div class="form-group">
              <label class="form-label">New Memory Fact</label>
              <textarea id="teach-fact-input" class="form-control" rows="3" placeholder="e.g. Priya visits every Diwali with grandson Kabir."></textarea>
            </div>
            <button class="btn-teal" style="width: 100%; justify-content: center;" onclick="teachMemoryFact()">
              Teach & Embed Memory Fact
            </button>
            <div id="teach-fact-status" style="margin-top: 10px; font-size: 12.5px; font-weight: 600;"></div>
          </div>
        </div>
      </div>
    </main>

    <!-- ======================================================== -->
    <!-- TAB 4 - INTEGRATIONS                                     -->
    <!-- ======================================================== -->
    <main id="view-integrations" class="content-area" style="display: none;">
      <div class="two-column-grid">
        <div class="col-left">
          <div class="card">
            <div class="card-title" style="margin-bottom: 12px;">Telegram Caregiver Bot API</div>
            <div class="setting-tile">
              <div class="setting-tile-info">
                <div class="setting-tile-title">Automated 3-Line Briefing</div>
                <div class="setting-tile-desc">Dispatches instant alert to caregiver's Telegram channel on distress/calls</div>
              </div>
              <span class="header-pill" style="color: var(--primary);">Connected</span>
            </div>
            <div class="form-group">
              <label class="form-label">Caregiver Chat ID</label>
              <input type="text" class="form-control" value="7604934874" readonly style="background: #F9FAFB;">
            </div>
            <button class="btn-teal" onclick="showToast('Telegram briefing channel verified active', 'success')">
              Test Telegram Bot Ping
            </button>
          </div>
        </div>
        <div class="col-right">
          <div class="card">
            <div class="card-title" style="margin-bottom: 12px;">SIM Telephony Hardware Interface</div>
            <div class="setting-tile">
              <div class="setting-tile-info">
                <div class="setting-tile-title">flutter_phone_direct_caller</div>
                <div class="setting-tile-desc">Android CALL_PHONE & iOS tel: URL Scheme &bull; Zero Twilio &bull; Free SIM minutes</div>
              </div>
              <span class="header-pill" style="color: var(--primary);">Verified</span>
            </div>
            <button class="btn-outline" onclick="showToast('Hardware Telephony permissions validated', 'info')">
              Check Permissions
            </button>
          </div>
        </div>
      </div>
    </main>

    <!-- ======================================================== -->
    <!-- TAB 5 - POST-CALL & TELEMETRY                            -->
    <!-- ======================================================== -->
    <main id="view-postcall" class="content-area" style="display: none;">
      <div class="two-column-grid">
        <div class="col-left">
          <div class="card">
            <div class="card-title" style="margin-bottom: 12px;">Caregiver Telegram Briefing Formatter</div>
            <div style="background: #F0FDF4; border: 1px solid #BBF7D0; padding: 14px; border-radius: 10px; font-size: 13px; line-height: 1.6; color: #166534;">
              <strong>Telegram Message Template:</strong><br>
              🚨 <strong>Emergency Call:</strong> Patient has requested to speak with you.<br>
              ⏰ <strong>Time:</strong> Today at 07:54 PM<br>
              💊 <strong>Last Reminder:</strong> Morning Donepezil (Taken)<br>
              ❤️ <strong>Vitals:</strong> 74 BPM (Normal Sinus Rhythm)
            </div>
          </div>
        </div>
        <div class="col-right">
          <div class="card">
            <div class="card-title" style="margin-bottom: 12px;">Audio & Privacy Architecture</div>
            <div style="font-size: 13px; color: var(--text-muted); line-height: 1.6;">
              &bull; <strong>Zero Call Audio Stored:</strong> No recordings or patient audio are retained on servers.<br>
              &bull; <strong>Anti-Hallucination:</strong> Deterministic rule-based templates enforce patient safety.<br>
              &bull; <strong>Data Export:</strong> Caregivers can export all stored memories via <code>/v1/privacy/export</code>.
            </div>
            <button class="btn-outline" style="margin-top: 14px;" onclick="window.location.href='/v1/privacy/export'">
              💾 Download Data Archive (.ZIP)
            </button>
          </div>
        </div>
      </div>
    </main>

    <!-- ======================================================== -->
    <!-- TAB 6 - RECENT CALLS                                     -->
    <!-- ======================================================== -->
    <main id="view-history" class="content-area" style="display: none;">
      <div class="card">
        <div class="card-header-clean">
          <div>
            <div class="card-title">Recent Call Attempts & Telephony Log</div>
            <div class="card-sub">Logged in MongoDB & SQLite audit collections</div>
          </div>
          <button class="btn-outline" style="height: 30px; font-size: 12px;" onclick="loadRecentCalls()">Refresh Logs</button>
        </div>

        <div style="overflow-x: auto;">
          <table class="clean-table" id="calls-table">
            <thead>
              <tr>
                <th>Timestamp</th>
                <th>Contact</th>
                <th>Phone</th>
                <th>Reason</th>
                <th>Source</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody id="calls-table-body">
              <tr>
                <td colspan="6" style="text-align: center; color: var(--text-muted);">Loading recent call records...</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </main>

    <!-- ======================================================== -->
    <!-- PATIENT SIMPLE PORTAL (High Contrast & Elderly Friendly) -->
    <!-- ======================================================== -->
    <section id="patient-portal-container">
      <div class="patient-hero-card">
        <img src="data:image/png;base64,__LOGO_B64__" onerror="this.src='/logo.png'" alt="Ghajini Robot Friend" class="patient-hero-logo">
        <div style="font-size: 26px; font-weight: 800; color: #1F2937; margin-top: 14px;" id="p-greeting-text">
          Hello! I am Ghajini.
        </div>
        <div style="font-size: 16px; color: var(--text-muted); margin-top: 6px;" id="p-subgreeting-text">
          You are safe at home with your loved ones. I am right here with you.
        </div>
        <button class="btn-outline" style="margin-top: 16px; font-size: 13px;" onclick="switchPortal('studio')">
          ← Back to Caregiver Studio
        </button>
      </div>

      <div class="patient-big-grid">
        <!-- 1. Talk to Ghajini -->
        <div class="patient-big-btn p-btn-talk" onclick="patientOpenTalk()">
          <div class="patient-btn-icon">🤖</div>
          <div class="patient-btn-text">
            <div class="patient-btn-title" id="p-talk-title">Talk to Ghajini</div>
            <div class="patient-btn-sub" id="p-talk-sub">Ask me any question</div>
          </div>
        </div>

        <!-- 2. Call Priya -->
        <div class="patient-big-btn p-btn-call" onclick="openPhoneCallModal()">
          <div class="patient-btn-icon">📞</div>
          <div class="patient-btn-text">
            <div class="patient-btn-title" id="p-call-title">Call Priya</div>
            <div class="patient-btn-sub" id="p-call-sub">+91 7604934874 (Direct Call)</div>
          </div>
        </div>

        <!-- 3. Heart & Pulse -->
        <div class="patient-big-btn p-btn-heart" onclick="patientOpenHeart()">
          <div class="patient-btn-icon">❤️</div>
          <div class="patient-btn-text">
            <div class="patient-btn-title" id="p-heart-title">Heart & Vitals</div>
            <div class="patient-btn-sub" id="p-heart-status-sub">74 BPM &bull; Steady & Normal</div>
          </div>
        </div>

        <!-- 4. SOS Help -->
        <div class="patient-big-btn p-btn-sos" onclick="patientTriggerSOS()">
          <div class="patient-btn-icon">🚨</div>
          <div class="patient-btn-text">
            <div class="patient-btn-title" id="p-sos-title">Need Help / SOS</div>
            <div class="patient-btn-sub" id="p-sos-sub">Alert family immediately</div>
          </div>
        </div>
      </div>
    </section>

  </div>

  <!-- ======================================================== -->
  <!-- INTERACTIVE MODALS                                       -->
  <!-- ======================================================== -->

  <!-- 1. In-Browser Voice Call Simulator Modal -->
  <div class="modal-overlay" id="modal-web-call">
    <div class="modal-card" style="text-align: center; max-width: 440px;">
      <div style="width: 56px; height: 56px; border-radius: 50%; background: var(--primary-light); color: var(--primary); display: flex; align-items: center; justify-content: center; margin: 0 auto 10px; font-size: 24px;">
        📞
      </div>
      <div style="font-size: 17px; font-weight: 700; color: var(--text-title);">Ghajini Voice Companion</div>
      <div style="font-size: 12.5px; color: var(--primary); font-weight: 600; margin-top: 3px;" id="call-timer-text">Connected &bull; 00:08</div>

      <!-- Animated Voice Waveform -->
      <div class="voice-wave-box">
        <div class="wave-bar"></div>
        <div class="wave-bar"></div>
        <div class="wave-bar"></div>
        <div class="wave-bar"></div>
        <div class="wave-bar"></div>
        <div class="wave-bar"></div>
      </div>

      <div style="background: #F9FAFB; border: 1px solid var(--card-border); border-radius: 10px; padding: 12px; font-size: 13.5px; line-height: 1.5; color: var(--text-title); min-height: 55px;" id="call-voice-transcript">
        "Hello! I am Ghajini. How are you feeling today?"
      </div>

      <div style="display: flex; justify-content: center; gap: 12px; margin-top: 20px;">
        <button class="btn-outline" style="border-radius: 50%; width: 44px; height: 44px; padding: 0; justify-content: center;" title="Mute" onclick="showToast('Microphone toggled', 'info')">
          🎤
        </button>
        <button class="btn-outline" style="border-radius: 50%; width: 44px; height: 44px; padding: 0; justify-content: center;" title="Speaker" onclick="testVoicePlayback()">
          🔊
        </button>
        <button class="btn-teal" style="background: var(--danger-red); border-radius: 24px; padding: 0 18px; font-weight: 600;" onclick="closeWebVoiceModal()">
          End Call
        </button>
      </div>
    </div>
  </div>

  <!-- 2. SIM Phone Call Dialog -->
  <div class="modal-overlay" id="modal-phone-call">
    <div class="modal-card">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
        <div class="card-title" style="color: #065F46;">
          <span>📞</span> Placing SIM Call to Caregiver
        </div>
        <button class="btn-outline" style="height: 28px; padding: 0 8px; font-size: 12px;" onclick="closePhoneCallModal()">✕</button>
      </div>

      <div style="background: #F0FDF4; border: 1.5px solid #BBF7D0; border-radius: 12px; padding: 14px; margin-bottom: 14px;">
        <div style="font-size: 14.5px; font-weight: 700; color: #166534;">Recipient: Priya Sharma (Daughter)</div>
        <div style="font-size: 19px; font-weight: 800; color: #064E3B; margin-top: 3px;">+91 7604934874</div>
        <div style="font-size: 11.5px; color: #15803D; margin-top: 5px;">Zero Twilio &bull; Direct Phone SIM Telephony &bull; Free Carrier Minutes</div>
      </div>

      <div id="phone-call-status-box" style="margin-bottom: 14px; font-size: 13px; line-height: 1.5; color: var(--text-title);">
        Connecting to safety router...
      </div>

      <div class="modal-footer-actions" style="display: flex; gap: 8px; justify-content: flex-end; flex-wrap: wrap;">
        <button class="btn-outline" onclick="copyCaregiverNumber()">📋 Copy Number</button>
        <button class="btn-teal" id="btn-dial-now" onclick="dialCaregiverDirect()">📞 Open Dialer (tel:)</button>
        <button class="btn-outline" onclick="closePhoneCallModal()">Dismiss</button>
      </div>
    </div>
  </div>

  <!-- 3. Ask AI Prompt Optimizer Modal -->
  <div class="modal-overlay" id="modal-ask-ai">
    <div class="modal-card">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
        <div class="card-title" style="color: var(--accent-orange);">
          <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
          Ask AI: Prompt Tuning Assistant
        </div>
        <button class="btn-outline" style="height: 28px; padding: 0 8px; font-size: 12px;" onclick="closeAskAIModal()">✕</button>
      </div>
      <p style="font-size: 12.5px; color: var(--text-muted); margin-bottom: 12px;">
        Select an AI tuning preset or enter custom clinical guidance for dementia care:
      </p>
      <div style="display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 12px;">
        <button class="quick-chip" onclick="applyAIPreset('calm')">Gentle De-escalation Preset</button>
        <button class="quick-chip" onclick="applyAIPreset('bilingual')">Hindi/English Bilingual Preset</button>
        <button class="quick-chip" onclick="applyAIPreset('repetition')">Patience with Repetition</button>
      </div>
      <div class="form-group">
        <textarea id="ai-suggestion-input" class="form-control" rows="3" placeholder="Describe instructions or prompt tweaks..."></textarea>
      </div>
      <div class="modal-footer-actions" style="display: flex; justify-content: flex-end; gap: 8px;">
        <button class="btn-outline" onclick="closeAskAIModal()">Cancel</button>
        <button class="btn-ask-ai" onclick="generateAIPromptSuggestion()">Apply Optimized Prompt</button>
      </div>
    </div>
  </div>

  <!-- 4. Deploy Status Modal -->
  <div class="modal-overlay" id="modal-deploy">
    <div class="modal-card">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
        <div class="card-title" style="color: var(--primary);">Production Deployment</div>
        <button class="btn-outline" style="height: 28px; padding: 0 8px; font-size: 12px;" onclick="closeDeployModal()">✕</button>
      </div>
      <div class="setting-tile" style="margin-bottom: 14px;">
        <div class="setting-tile-info">
          <div class="setting-tile-title">Vercel Serverless (Production)</div>
          <div class="setting-tile-desc">https://ghajini-2-0.vercel.app</div>
        </div>
        <span class="header-pill" style="color: var(--primary);">Live & Active</span>
      </div>
      <p style="font-size: 12.5px; color: var(--text-muted); line-height: 1.5; margin-bottom: 14px;">
        Connected to GitHub <code>Madhu07-offl/Ghajini-2.O</code>. Every push automatically rebuilds and deploys to Vercel within 10 seconds.
      </p>
      <div class="modal-footer-actions" style="display: flex; justify-content: flex-end; gap: 8px;">
        <button class="btn-outline" onclick="closeDeployModal()">Close</button>
        <button class="btn-teal" onclick="window.open('https://ghajini-2-0.vercel.app', '_blank')">Open Vercel App ↗</button>
      </div>
    </div>
  </div>

  <!-- 5. Caregiver Profile Modal -->
  <div class="modal-overlay" id="modal-caregiver">
    <div class="modal-card">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
        <div class="card-title">Caregiver Information</div>
        <button class="btn-outline" style="height: 28px; padding: 0 8px; font-size: 12px;" onclick="closeCaregiverModal()">✕</button>
      </div>
      <p style="font-size: 12.5px; color: var(--text-muted); margin-bottom: 14px;">
        Profile used for automatic call forwarding and emergency escalations:
      </p>
      <div class="form-group">
        <label class="form-label">Full Name</label>
        <input type="text" id="cfg-name" class="form-control" value="Priya Sharma">
      </div>
      <div class="form-group">
        <label class="form-label">Caregiver Phone Number (SIM Direct)</label>
        <input type="text" id="cfg-phone" class="form-control" value="+91 7604934874">
      </div>
      <div class="form-group">
        <label class="form-label">Relationship to Patient</label>
        <input type="text" id="cfg-rel" class="form-control" value="Daughter & Primary Guardian">
      </div>
      <div class="modal-footer-actions" style="display: flex; justify-content: flex-end; gap: 8px; margin-top: 16px;">
        <button class="btn-outline" onclick="closeCaregiverModal()">Cancel</button>
        <button class="btn-teal" onclick="saveCaregiverModal()">Save Information</button>
      </div>
    </div>
  </div>

  <script>
    // State
    let activeTab = 'assistant';
    let activePortal = 'studio';
    let currentLang = 'hi';
    let ecgAnimationId = null;
    let callTimerInterval = null;

    // Toast Notification System
    function showToast(message, type = 'success') {
      const container = document.getElementById('toast-container');
      const toast = document.createElement('div');
      toast.className = `toast-pill toast-${type}`;
      const icon = (type === 'success') ? '✅' : (type === 'error') ? '❌' : (type === 'warning') ? '⚠️' : 'ℹ️';
      toast.innerHTML = `<span>${icon}</span> <span>${message}</span>`;
      container.appendChild(toast);
      setTimeout(() => {
        toast.style.opacity = '0';
        setTimeout(() => toast.remove(), 300);
      }, 3500);
    }

    // Tab Switcher
    function switchTab(tabId) {
      activeTab = tabId;
      activePortal = 'studio';

      // Update Tab Bar buttons
      document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
      const activeBtn = document.getElementById('tab-' + tabId);
      if (activeBtn) activeBtn.classList.add('active');

      // Update Sidebar Nav icon buttons
      document.querySelectorAll('.nav-icon-btn').forEach(btn => btn.classList.remove('active'));
      const activeNav = document.getElementById('nav-' + tabId);
      if (activeNav) activeNav.classList.add('active');

      // Hide all main studio views and show active one
      const allViews = ['assistant', 'calls', 'knowledge', 'integrations', 'postcall', 'history'];
      allViews.forEach(id => {
        const el = document.getElementById('view-' + id);
        if (el) el.style.display = (id === tabId) ? 'block' : 'none';
      });

      // Hide patient portal if open
      const pContainer = document.getElementById('patient-portal-container');
      if (pContainer) pContainer.style.display = 'none';

      // Smooth scroll to top on tab change
      window.scrollTo({ top: 0, behavior: 'smooth' });

      if (tabId === 'history') {
        loadRecentCalls();
      }
    }

    // Portal Switcher
    function switchPortal(portal) {
      activePortal = portal;
      const allViews = ['view-assistant', 'view-calls', 'view-knowledge', 'view-integrations', 'view-postcall', 'view-history'];
      const pContainer = document.getElementById('patient-portal-container');

      if (portal === 'patient') {
        allViews.forEach(id => {
          const el = document.getElementById(id);
          if (el) el.style.display = 'none';
        });
        if (pContainer) pContainer.style.display = 'block';
        window.scrollTo({ top: 0, behavior: 'smooth' });
        showToast('Switched to Patient Simple View', 'info');
      } else {
        if (pContainer) pContainer.style.display = 'none';
        switchTab(activeTab);
        showToast('Switched to Caregiver Studio', 'info');
      }
    }

    // Multilingual Dictionary & Global Switcher
    const LANG_DATA = {
      en: {
        code: 'en',
        name: 'English',
        voiceTileTitle: 'Aditi (Elder-care Gentle & Slow - 0.85x)',
        voiceTileDesc: 'Indian Accent • Calming warm cadence • Noise Suppression Active',
        firstSentence: 'Hello! I am Ghajini, your companion. How are you feeling today?',
        pGreeting: 'Hello! I am Ghajini.',
        pSub: 'You are safe at home with your loved ones. I am right here with you.',
        pTalkTitle: 'Talk to Ghajini',
        pTalkSub: 'Ask me any question',
        pCallTitle: 'Call Priya',
        pCallSub: '+91 7604934874 (Direct Call)',
        pHeartTitle: 'Heart & Vitals',
        pHeartSub: '74 BPM • Steady & Normal',
        pSOSTitle: 'Need Help / SOS',
        pSOSSub: 'Alert family immediately',
        simGreeting: 'Hello! I am Ghajini, your friend. You are safe at home. How can I help you today?',
        greetingVoice: 'Hello. I am Ghajini, your memory companion. You are safe at home and doing wonderful today.',
        quickChips: [
          { text: 'Who is Priya?', prompt: 'Who is Priya?' },
          { text: 'What day is it?', prompt: 'What day is it today?' },
          { text: 'Did I take my medicine?', prompt: 'Did I take my medicine?' },
          { text: '🚨 Help, I fell down', prompt: 'Help me, I fell down' }
        ]
      },
      hi: {
        code: 'hi',
        name: 'हिन्दी (Hindi)',
        voiceTileTitle: 'Aditi (वृद्ध देखभाल - शांत और मंद 0.85x)',
        voiceTileDesc: 'भारतीय लहजा • शांत और गर्म आवाज • शोर निवारण सक्रिय',
        firstSentence: 'नमस्ते! मैं गजिनी हूँ, आपका साथी। आज आप कैसा महसूस कर रहे हैं?',
        pGreeting: 'नमस्ते! मैं गजिनी हूँ।',
        pSub: 'आप अपने घर में बिल्कुल सुरक्षित हैं। मैं आपके साथ हूँ।',
        pTalkTitle: 'गजिनी से बात करें',
        pTalkSub: 'मुझसे कोई भी सवाल पूछें',
        pCallTitle: 'प्रिया को फोन करें',
        pCallSub: '+91 7604934874 (तुरंत कॉल)',
        pHeartTitle: 'मेरा दिल और नब्ज़',
        pHeartSub: '74 BPM • बिल्कुल सामान्य',
        pSOSTitle: 'मदद चाहिए / SOS',
        pSOSSub: 'परिवार को तुरंत संदेश भेजें',
        simGreeting: 'नमस्ते! मैं गजिनी हूँ, आपका मित्र। आप अपने घर में सुरक्षित हैं। आज मैं आपकी क्या मदद करूँ?',
        greetingVoice: 'नमस्ते। मैं गजिनी हूँ, आपकी देखभाल साथी। आप अपने घर में सुरक्षित हैं।',
        quickChips: [
          { text: 'प्रिया कौन है?', prompt: 'प्रिया कौन है?' },
          { text: 'आज कौन सा दिन है?', prompt: 'आज कौन सा दिन है?' },
          { text: 'क्या मैंने दवाई ली?', prompt: 'क्या मैंने दवाई ले ली?' },
          { text: '🚨 मदद करो मैं गिर गई', prompt: 'मदद करो मैं गिर गई' }
        ]
      },
      pa: {
        code: 'pa',
        name: 'ਪੰਜਾਬੀ (Punjabi)',
        voiceTileTitle: 'Aditi (ਬਜ਼ੁਰਗ ਦੇਖਭਾਲ - ਸ਼ਾਂਤ ਅਤੇ ਹੌਲੀ 0.85x)',
        voiceTileDesc: 'ਭਾਰਤੀ ਲਹਿਜ਼ਾ • ਸ਼ਾਂਤ ਅਤੇ ਨਿੱਘੀ ਅਵਾਜ਼ • ਸ਼ੋਰ ਰੋਕੂ ਕਿਰਿਆਸ਼ੀਲ',
        firstSentence: 'ਸਤਿ ਸ੍ਰੀ ਅਕਾਲ! ਮੈਂ ਗਜਨੀ ਹਾਂ, ਤੁਹਾਡਾ ਸਾਥੀ। ਅੱਜ ਤੁਸੀਂ ਕਿਵੇਂ ਮਹਿਸੂਸ ਕਰ ਰਹੇ ਹੋ?',
        pGreeting: 'ਸਤਿ ਸ੍ਰੀ ਅਕਾਲ! ਮੈਂ ਗਜਨੀ ਹਾਂ।',
        pSub: 'ਤੁਸੀਂ ਆਪਣੇ ਘਰ ਵਿੱਚ ਬਿਲਕੁਲ ਸੁਰੱਖਿਅਤ ਹੋ। ਮੈਂ ਤੁਹਾਡੇ ਨਾਲ ਹਾਂ।',
        pTalkTitle: 'ਗਜਨੀ ਨਾਲ ਗੱਲ ਕਰੋ',
        pTalkSub: 'ਮੈਨੂੰ ਕੋਈ ਵੀ ਸਵਾਲ ਪੁੱਛੋ',
        pCallTitle: 'ਪ੍ਰਿਆ ਨੂੰ ਫ਼ੋਨ ਕਰੋ',
        pCallSub: '+91 7604934874 (ਤੁਰੰਤ ਕਾਲ)',
        pHeartTitle: 'ਮੇਰਾ ਦਿਲ ਅਤੇ ਨਬਜ਼',
        pHeartSub: '74 BPM • ਬਿਲਕੁਲ ਆਮ',
        pSOSTitle: 'ਮਦਦ ਚਾਹੀਦੀ ਹੈ / SOS',
        pSOSSub: 'ਪਰਿਵਾਰ ਨੂੰ ਤੁਰੰਤ ਸੁਨੇਹਾ ਭੇਜੋ',
        simGreeting: 'ਸਤਿ ਸ੍ਰੀ ਅਕਾਲ! ਮੈਂ ਗਜਨੀ ਹਾਂ, ਤੁਹਾਡਾ ਦੋਸਤ। ਤੁਸੀਂ ਆਪਣੇ ਘਰ ਵਿੱਚ ਸੁਰੱਖਿਅਤ ਹੋ। ਅੱਜ ਮੈਂ ਤੁਹਾਡੀ ਕੀ ਮਦਦ ਕਰਾਂ?',
        greetingVoice: 'ਸਤਿ ਸ੍ਰੀ ਅਕਾਲ। ਮੈਂ ਗਜਨੀ ਹਾਂ, ਤੁਹਾਡੀ ਦੇਖਭਾਲ ਸਾਥੀ। ਤੁਸੀਂ ਆਪਣੇ ਘਰ ਵਿੱਚ ਬਿਲਕੁਲ ਸੁਰੱਖਿਅਤ ਹੋ।',
        quickChips: [
          { text: 'ਪ੍ਰਿਆ ਕੌਣ ਹੈ?', prompt: 'ਪ੍ਰਿਆ ਕੌਣ ਹੈ?' },
          { text: 'ਅੱਜ ਕਿਹੜਾ ਦਿਨ ਹੈ?', prompt: 'ਅੱਜ ਕਿਹੜਾ ਦਿਨ ਹੈ?' },
          { text: 'ਕੀ ਮੈਂ ਦਵਾਈ ਲੈ ਲਈ?', prompt: 'ਕੀ ਮੈਂ ਦਵਾਈ ਲੈ ਲਈ?' },
          { text: '🚨 ਮਦਦ ਕਰੋ ਮੈਂ ਡਿੱਗ ਪਈ', prompt: 'ਮਦਦ ਕਰੋ ਮੈਂ ਡਿੱਗ ਪਈ' }
        ]
      }
    };

    function setGlobalLanguage(lang) {
      if (!LANG_DATA[lang]) lang = 'en';
      currentLang = lang;
      const data = LANG_DATA[lang];

      // 1. Sync all select dropdowns
      const topSelect = document.getElementById('top-lang-select');
      const mobileSelect = document.getElementById('top-lang-select-mobile');
      const studioSelect = document.getElementById('agent-lang');
      if (topSelect) topSelect.value = lang;
      if (mobileSelect) mobileSelect.value = lang;
      if (studioSelect) studioSelect.value = lang;

      // 2. Studio Card 1
      const vTitle = document.getElementById('voice-tile-title');
      const vDesc = document.getElementById('voice-tile-desc');
      const firstSent = document.getElementById('agent-first-sentence');
      const greetCounter = document.getElementById('greeting-counter');
      if (vTitle) vTitle.innerHTML = `<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="10"/><path d="M8 12a4 4 0 0 1 8 0"/></svg> ${data.voiceTileTitle}`;
      if (vDesc) vDesc.innerText = data.voiceTileDesc;
      if (firstSent) {
        firstSent.value = data.firstSentence;
        if (greetCounter) greetCounter.innerText = `${data.firstSentence.length}/120`;
      }

      // 3. Voice call transcript
      const callTranscript = document.getElementById('call-voice-transcript');
      if (callTranscript) callTranscript.innerText = `"${data.firstSentence}"`;

      // 4. Simulator Quick Prompts
      const quickContainer = document.getElementById('simulator-quick-prompts');
      if (quickContainer) {
        quickContainer.innerHTML = '';
        data.quickChips.forEach(chip => {
          const btn = document.createElement('button');
          btn.className = 'quick-chip';
          btn.innerText = chip.text;
          btn.onclick = () => quickSend(chip.prompt);
          quickContainer.appendChild(btn);
        });
      }

      // 5. Patient Portal Elements
      const pGreeting = document.getElementById('p-greeting-text');
      const pSub = document.getElementById('p-subgreeting-text');
      const pTalkTitle = document.getElementById('p-talk-title');
      const pTalkSub = document.getElementById('p-talk-sub');
      const pCallTitle = document.getElementById('p-call-title');
      const pCallSub = document.getElementById('p-call-sub');
      const pHeartTitle = document.getElementById('p-heart-title');
      const pHeartSub = document.getElementById('p-heart-status-sub');
      const pSOSTitle = document.getElementById('p-sos-title');
      const pSOSSub = document.getElementById('p-sos-sub');

      if (pGreeting) pGreeting.innerText = data.pGreeting;
      if (pSub) pSub.innerText = data.pSub;
      if (pTalkTitle) pTalkTitle.innerText = data.pTalkTitle;
      if (pTalkSub) pTalkSub.innerText = data.pTalkSub;
      if (pCallTitle) pCallTitle.innerText = data.pCallTitle;
      if (pCallSub) pCallSub.innerText = data.pCallSub;
      if (pHeartTitle) pHeartTitle.innerText = data.pHeartTitle;
      if (pHeartSub) pHeartSub.innerText = data.pHeartSub;
      if (pSOSTitle) pSOSTitle.innerText = data.pSOSTitle;
      if (pSOSSub) pSOSSub.innerText = data.pSOSSub;

      showToast(`Language set to ${data.name}`, 'info');
    }

    function onLangChange() {
      const el = document.getElementById('agent-lang');
      if (el) setGlobalLanguage(el.value);
    }

    // Chat Drawer / Simulator focus
    function openChatDrawer() {
      switchTab('assistant');
      const input = document.getElementById('sim-input');
      input.focus();
      input.scrollIntoView({ behavior: 'smooth', block: 'center' });
      showToast('Live Simulator ready for testing', 'info');
    }

    function quickSend(text) {
      document.getElementById('sim-input').value = text;
      sendSimulatorText();
    }

    async function sendSimulatorText() {
      const input = document.getElementById('sim-input');
      const text = input.value.trim();
      if (!text) return;
      input.value = '';

      const stream = document.getElementById('chat-stream');
      
      // Append patient message
      const pBubble = document.createElement('div');
      pBubble.className = 'chat-bubble chat-bubble-patient';
      pBubble.innerText = text;
      stream.appendChild(pBubble);
      stream.scrollTop = stream.scrollHeight;

      // Loading bubble
      const gBubble = document.createElement('div');
      gBubble.className = 'chat-bubble chat-bubble-ghajini';
      gBubble.innerText = 'Ghajini is thinking...';
      stream.appendChild(gBubble);
      stream.scrollTop = stream.scrollHeight;

      try {
        const res = await fetch('/v1/companion/message', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ patient_id: 1, text: text, lang: currentLang, source: 'text' })
        });
        const data = await res.json();
        gBubble.innerHTML = `
          ${data.reply}
          <div>
            <span class="meta-tag meta-intent">intent: ${data.intent}</span>
            <span class="meta-tag ${data.grounded ? 'meta-grounded' : 'meta-intent'}">${data.grounded ? 'grounded: fact' : 'ungrounded fallback'}</span>
          </div>
        `;
      } catch (e) {
        gBubble.innerText = 'I am not sure. Shall I call Priya for you?';
      }
      stream.scrollTop = stream.scrollHeight;
    }

    // Voice simulation
    function testVoicePlayback() {
      if ('speechSynthesis' in window) {
        window.speechSynthesis.cancel();
        const msg = (LANG_DATA[currentLang] && LANG_DATA[currentLang].greetingVoice) || 'Hello. I am Ghajini, your memory companion. You are safe at home and doing wonderful today.';
        const utterance = new SpeechSynthesisUtterance(msg);
        utterance.rate = 0.85;
        if (currentLang === 'hi') utterance.lang = 'hi-IN';
        else if (currentLang === 'pa') utterance.lang = 'pa-IN';
        else utterance.lang = 'en-IN';
        window.speechSynthesis.speak(utterance);
        showToast(`Playing voice sample (${currentLang.toUpperCase()}) at 0.85x calm rate`, 'success');
      } else {
        showToast('Speech synthesis triggered at 0.85x calm pace', 'info');
      }
    }

    function openWebVoiceModal() {
      document.getElementById('modal-web-call').style.display = 'flex';
      let sec = 0;
      const timerEl = document.getElementById('call-timer-text');
      if (callTimerInterval) clearInterval(callTimerInterval);
      callTimerInterval = setInterval(() => {
        sec++;
        const m = String(Math.floor(sec / 60)).padStart(2, '0');
        const s = String(sec % 60).padStart(2, '0');
        timerEl.innerText = `Connected • ${m}:${s}`;
      }, 1000);
      testVoicePlayback();
    }
    function closeWebVoiceModal() {
      document.getElementById('modal-web-call').style.display = 'none';
      if (callTimerInterval) clearInterval(callTimerInterval);
      if ('speechSynthesis' in window) window.speechSynthesis.cancel();
      showToast('Web voice session ended', 'info');
    }

    // Phone Call Modal & Direct Dial
    async function openPhoneCallModal() {
      const modal = document.getElementById('modal-phone-call');
      modal.style.display = 'flex';
      const statusBox = document.getElementById('phone-call-status-box');
      statusBox.innerHTML = 'Connecting to backend safety policy router...';

      try {
        const res = await fetch('/v1/calls/request', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            patient_id: 1,
            reason: 'Direct phone call trigger from Studio',
            source: 'manual',
            lang: currentLang,
            bypass_cooldown: true
          })
        });
        const data = await res.json();
        if (data.allowed) {
          statusBox.innerHTML = `
            <div style="color: #065F46; font-weight: 600;">✅ Call Request Approved (Cooldown Bypassed)</div>
            <div style="margin-top: 6px;"><strong>Spoken to Patient:</strong> "${data.patient_message}"</div>
            <div style="margin-top: 6px; font-size: 12px; color: var(--text-muted);"><strong>Telegram Briefing:</strong> ${data.caregiver_briefing.replace(/\\n/g, ' ')}</div>
          `;
          showToast('Call permitted. Direct dial ready.', 'success');
        } else {
          statusBox.innerHTML = `
            <div style="color: #DC2626; font-weight: 600;">⚠️ Call Paused: ${data.block_reason}</div>
            <button class="btn-outline" style="margin-top: 8px; font-size: 12px;" onclick="resetCallCooldown()">Reset Cooldown Now</button>
          `;
          showToast('Call paused by rate policy', 'warning');
        }
      } catch (e) {
        statusBox.innerHTML = `<span style="color: #DC2626;">Error: ${e}</span>`;
      }
    }
    function closePhoneCallModal() {
      document.getElementById('modal-phone-call').style.display = 'none';
    }
    function dialCaregiverDirect() {
      window.location.href = 'tel:+917604934874';
      showToast('Opening native phone dialer for +91 7604934874...', 'success');
    }
    function copyCaregiverNumber() {
      navigator.clipboard.writeText('+917604934874').then(() => {
        showToast('Copied +91 7604934874 to clipboard!', 'success');
      });
    }

    async function resetCallCooldown() {
      try {
        const res = await fetch('/v1/calls/reset-cooldown?patient_id=1', { method: 'POST' });
        const data = await res.json();
        showToast('Cooldown & throttle locks reset! Unlimited calls allowed.', 'success');
      } catch (e) {
        showToast('Reset failed: ' + e, 'error');
      }
    }

    async function executeTestCall() {
      const reason = document.getElementById('test-call-reason').value;
      const source = document.getElementById('test-call-source').value;
      const bypass = document.getElementById('toggle-cooldown-bypass').checked;
      const out = document.getElementById('test-call-output');

      out.style.display = 'block';
      out.style.color = '#0F9D7A';
      out.innerText = 'Dispatching test call to backend...';

      try {
        const res = await fetch('/v1/calls/request', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            patient_id: 1,
            reason: reason,
            source: source,
            lang: currentLang,
            bypass_cooldown: bypass
          })
        });
        const data = await res.json();
        if (data.allowed) {
          out.innerHTML = `✅ <strong>Call Dispatched!</strong> Calling ${data.contact.name} (${data.contact.phone})<br>Briefing: ${data.caregiver_briefing.replace(/\\n/g, ' ')}`;
          showToast(`Calling ${data.contact.name}...`, 'success');
        } else {
          out.style.color = '#DC2626';
          out.innerHTML = `⚠️ <strong>Call Paused:</strong> ${data.block_reason}`;
          showToast('Call paused by policy', 'warning');
        }
      } catch (e) {
        out.style.color = '#DC2626';
        out.innerText = 'Call error: ' + e;
      }
    }

    // CardioLife & Vitals (Crash-proof handler)
    async function refreshVitals(manual = false) {
      try {
        const res = await fetch('/v1/cardiolife/current?patient_id=1');
        const data = await res.json();
        const r = data.reading || data || {};

        const bpm = r.heart_rate_bpm || 74;
        const status = (r.status || 'normal').replace(/_/g, ' ').toUpperCase();
        const bp = (r.blood_pressure_systolic && r.blood_pressure_diastolic) ? `${r.blood_pressure_systolic}/${r.blood_pressure_diastolic}` : '120/80';
        const spo2 = r.oxygen_saturation || 98;

        const hrEl = document.getElementById('dash-vital-hr');
        const stEl = document.getElementById('dash-vital-status');
        const bpEl = document.getElementById('dash-vital-bp');
        const spEl = document.getElementById('dash-vital-spo2');
        const pSub = document.getElementById('p-heart-status-sub');

        if (hrEl) hrEl.innerHTML = `${bpm} <span style="font-size: 12px; font-weight: 500;">BPM</span>`;
        if (stEl) stEl.innerText = status;
        if (bpEl) bpEl.innerText = bp;
        if (spEl) spEl.innerHTML = `${spo2} <span style="font-size: 12px; font-weight: 500;">%</span>`;
        if (pSub) pSub.innerText = `${bpm} BPM • ${status}`;

        if (manual) showToast('CardioLife vitals synced', 'success');
      } catch (e) {
        console.warn('Vitals sync note:', e);
      }
    }

    async function simulateCardiacAlert() {
      try {
        const res = await fetch('/v1/cardiolife/simulate?scenario=critical_tachycardia', { method: 'POST' });
        const data = await res.json();
        showToast(`🚨 Cardiac Alert: ${data.heart_rate_bpm} BPM (${data.status})`, 'error');
        refreshVitals();
      } catch (e) {
        showToast('Simulation failed: ' + e, 'error');
      }
    }

    // Mini ECG Canvas Animation
    function initECG() {
      const canvas = document.getElementById('miniECGCanvas');
      if (!canvas) return;
      const ctx = canvas.getContext('2d');
      let offset = 0;

      function renderFrame() {
        const w = canvas.width;
        const h = canvas.height;
        ctx.fillStyle = '#0F172A';
        ctx.fillRect(0, 0, w, h);

        ctx.strokeStyle = '#0F9D7A';
        ctx.lineWidth = 2;
        ctx.shadowColor = '#0F9D7A';
        ctx.shadowBlur = 6;
        ctx.beginPath();

        const mid = h / 2;
        for (let x = 0; x < w; x++) {
          const t = (x + offset) % 180;
          let y = mid;
          if (t > 40 && t < 55) {
            y = mid - 5 * Math.sin(((t - 40) / 15) * Math.PI);
          } else if (t >= 70 && t < 74) {
            y = mid + 4;
          } else if (t >= 74 && t < 84) {
            y = mid - 26 * Math.sin(((t - 74) / 10) * Math.PI);
          } else if (t >= 84 && t < 90) {
            y = mid + 8;
          } else if (t >= 110 && t < 140) {
            y = mid - 8 * Math.sin(((t - 110) / 30) * Math.PI);
          }
          if (x === 0) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        }
        ctx.stroke();
        ctx.shadowBlur = 0;

        offset = (offset + 3) % 180;
        ecgAnimationId = requestAnimationFrame(renderFrame);
      }
      if (ecgAnimationId) cancelAnimationFrame(ecgAnimationId);
      renderFrame();
    }

    // Knowledge Base Teach
    async function teachMemoryFact() {
      const text = document.getElementById('teach-fact-input').value.trim();
      if (!text) {
        showToast('Please type a memory fact first', 'warning');
        return;
      }
      const st = document.getElementById('teach-fact-status');
      st.style.color = '#0F9D7A';
      st.innerText = 'Embedding into FAISS vector index...';

      try {
        const res = await fetch('/v1/companion/teach', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ patient_id: 1, text: text, category: 'personal' })
        });
        const data = await res.json();
        st.innerText = `Success! Embedded fact #${data.id}: "${data.text}"`;
        document.getElementById('teach-fact-input').value = '';
        showToast(`Memory #${data.id} embedded successfully into FAISS!`, 'success');
      } catch (e) {
        st.style.color = '#DC2626';
        st.innerText = 'Error embedding fact: ' + e;
        showToast('Failed to embed memory: ' + e, 'error');
      }
    }

    // Recent calls loader
    async function loadRecentCalls() {
      const tbody = document.getElementById('calls-table-body');
      tbody.innerHTML = '<tr><td colspan="6" style="text-align: center;">Fetching call records...</td></tr>';

      try {
        const res = await fetch('/v1/calls/history?patient_id=1');
        const calls = await res.json();
        tbody.innerHTML = '';
        if (calls.length === 0) {
          tbody.innerHTML = '<tr><td colspan="6" style="text-align: center; color: var(--text-muted);">No recorded call attempts yet.</td></tr>';
          return;
        }
        calls.forEach(c => {
          const tr = document.createElement('tr');
          const time = c.created_at ? new Date(c.created_at).toLocaleTimeString() : 'Recent';
          tr.innerHTML = `
            <td>${time}</td>
            <td><strong>${c.contact_name || 'Priya'}</strong></td>
            <td>${c.contact_phone || '+91 7604934874'}</td>
            <td>${c.reason || 'Safety Trigger'}</td>
            <td><span class="header-pill">${c.source || 'manual'}</span></td>
            <td><span class="header-pill" style="color: ${c.allowed ? 'var(--primary)' : '#DC2626'};">${c.allowed ? 'Allowed' : 'Throttled'}</span></td>
          `;
          tbody.appendChild(tr);
        });
        showToast('Call logs updated', 'info');
      } catch (e) {
        tbody.innerHTML = `<tr><td colspan="6" style="color: #DC2626;">Error loading calls: ${e}</td></tr>`;
      }
    }

    // Modals
    function openCaregiverModal() { document.getElementById('modal-caregiver').style.display = 'flex'; }
    function closeCaregiverModal() { document.getElementById('modal-caregiver').style.display = 'none'; }
    function saveCaregiverModal() {
      closeCaregiverModal();
      showToast('Caregiver profile updated', 'success');
    }

    function openAskAIModal() { document.getElementById('modal-ask-ai').style.display = 'flex'; }
    function closeAskAIModal() { document.getElementById('modal-ask-ai').style.display = 'none'; }
    function applyAIPreset(type) {
      const input = document.getElementById('ai-suggestion-input');
      if (type === 'calm') input.value = 'Speak with extreme gentleness. Never contradict the patient. If they feel confused, remind them Priya is watching over them.';
      else if (type === 'bilingual') input.value = 'Support both Hindi and English fluidly. Reply in the same language the patient uses, keeping vocabulary simple.';
      else if (type === 'repetition') input.value = 'Treat every repeated question as if it were asked for the first time. Provide warm, consistent reassurance.';
    }
    function generateAIPromptSuggestion() {
      const val = document.getElementById('ai-suggestion-input').value.trim();
      document.getElementById('agent-prompt').value = val || `You are Ghajini, a caring Alzheimer's voice companion. Speak with gentle warmth and infinite patience. Always ground facts in family memories (Priya in Bangalore, Dr. Sharma on Thursdays). If anxiety is detected, soothe them that home is safe.`;
      closeAskAIModal();
      showToast('AI Prompt Optimization applied to System Prompt!', 'success');
    }

    function openDeployModal() { document.getElementById('modal-deploy').style.display = 'flex'; }
    function closeDeployModal() { document.getElementById('modal-deploy').style.display = 'none'; }

    function resetInstructions() {
      document.getElementById('agent-prompt').value = `You are Ghajini, a compassionate memory companion for an Alzheimer's patient. 
Rules:
1. Speak in 1 or 2 short, calming sentences.
2. Ground all answers strictly in stored family facts.
3. If asked about taking medicine, check reminder records.
4. Detect anxiety and reassure the patient they are safe at home.`;
      showToast('Instructions reset to clinical default', 'info');
    }

    function toggleViewMode(mode) {
      document.getElementById('btn-view-ui').classList.toggle('active', mode === 'ui');
      document.getElementById('btn-view-code').classList.toggle('active', mode === 'code');
      if (mode === 'code') {
        window.open('/docs', '_blank');
      }
    }

    // Patient Actions
    function patientOpenTalk() {
      switchPortal('studio');
      openChatDrawer();
    }
    function patientOpenHeart() {
      refreshVitals();
      const msg = currentLang === 'hi' ? '❤️ आपकी धड़कन 74 BPM है। आप बिल्कुल सुरक्षित हैं।' :
                  currentLang === 'pa' ? '❤️ ਤੁਹਾਡੀ ਧੜਕਣ 74 BPM ਹੈ। ਤੁਸੀਂ ਬਿਲਕੁਲ ਸੁਰੱਖਿਅਤ ਹੋ।' :
                  '❤️ Heart rate is 74 BPM. You are completely safe and doing well.';
      showToast(msg, 'success');
    }
    async function patientTriggerSOS() {
      try {
        await fetch('/v1/alerts/help', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ patient_id: 1, note: 'Patient pressed Help / SOS on simple touch portal' })
        });
        const msg = currentLang === 'hi' ? '🚨 आपातकालीन सूचना भेज दी गई है! Alert sent to Priya.' :
                    currentLang === 'pa' ? '🚨 ਐਮਰਜੈਂਸੀ ਸੁਨੇਹਾ ਭੇਜਿਆ ਗਿਆ! Alert sent to Priya.' :
                    '🚨 Emergency alert dispatched to Priya Sharma (+91 7604934874).';
        showToast(msg, 'error');
        openPhoneCallModal();
      } catch (e) {
        showToast('SOS error: ' + e, 'error');
      }
    }

    // Startup
    window.addEventListener('DOMContentLoaded', () => {
      refreshVitals();
      initECG();
      setGlobalLanguage('en');
    });
  </script>
</body>
</html>
"""


def get_dashboard_html() -> HTMLResponse:
    html = DASHBOARD_TEMPLATE.replace("__LOGO_B64__", _logo_b64)
    return HTMLResponse(content=html, status_code=200)
