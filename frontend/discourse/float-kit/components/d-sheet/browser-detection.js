/**
 * Browser detection utilities.
 * Used for platform-specific behavior, particularly snap accelerator calculations.
 */

/**
 * Detect browser engine and platform.
 * @returns {{ browserEngine: string, platform: string }}
 *   browserEngine: "chromium" | "webkit" | "gecko" | "unknown"
 *   platform: "ios" | "ipados" | "android" | "macos" | "unknown"
 */
function detectBrowser() {
  const userAgent = window.navigator.userAgent;
  let browserEngine = "unknown";
  let platform = "unknown";

  // Check userAgentData first (modern browsers)
  if (navigator.userAgentData) {
    const brands = navigator.userAgentData.brands;
    if (brands?.some((b) => b.brand === "Chromium")) {
      browserEngine = "chromium";
    }
    if (navigator.userAgentData.platform === "Android") {
      platform = "android";
    }
  }

  // Fallback to userAgent string for platform
  if (platform === "unknown" && userAgent?.match(/android/i)) {
    platform = "android";
  }

  // Fallback to userAgent string for browser engine
  if (browserEngine === "unknown") {
    if (userAgent?.match(/Chrome/i)) {
      browserEngine = "chromium";
    } else if (userAgent?.match(/Firefox/i)) {
      browserEngine = "gecko";
    } else if (userAgent?.match(/Safari|iPhone/i)) {
      browserEngine = "webkit";
    }
  }

  // Detect iOS/iPadOS/macOS for WebKit browsers
  if (browserEngine === "webkit") {
    if (userAgent?.match(/iPhone/i)) {
      platform = "ios";
    } else if (userAgent?.match(/iPad/i)) {
      platform = "ipados";
    } else if (userAgent?.match(/Macintosh/i)) {
      // Check for iPad pretending to be Mac (iPadOS 13+)
      try {
        document.createEvent("TouchEvent");
        platform = "ipados";
      } catch {
        platform = "macos";
      }
    }
  }

  return { browserEngine, platform };
}

// Cache browser detection result
let browserInfoCache = null;

/**
 * Get cached browser info.
 * @returns {{ browserEngine: string, platform: string }}
 */
export function getBrowserInfo() {
  if (!browserInfoCache) {
    browserInfoCache = detectBrowser();
  }
  return browserInfoCache;
}

/**
 * Check if running on Chromium-based browser.
 * @returns {boolean}
 */
export function isChromium() {
  return getBrowserInfo().browserEngine === "chromium";
}

/**
 * Check if running on WebKit-based browser (Safari, iOS).
 * @returns {boolean}
 */
export function isWebKit() {
  return getBrowserInfo().browserEngine === "webkit";
}

/**
 * Check if running on iOS or iPadOS.
 * @returns {boolean}
 */
export function isAppleMobile() {
  const { platform } = getBrowserInfo();
  return platform === "ios" || platform === "ipados";
}

/**
 * Check if running on Android.
 * @returns {boolean}
 */
export function isAndroid() {
  return getBrowserInfo().platform === "android";
}
