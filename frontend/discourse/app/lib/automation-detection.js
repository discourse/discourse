import { isRailsTesting, isTesting } from "discourse/lib/environment";

export function isAutomationDetected() {
  // Our own test suites drive the browser with WebDriver but still need
  // pageview tracking to fire.
  if (isTesting() || isRailsTesting()) {
    return false;
  }

  return !!(
    window.navigator.webdriver ||
    window.Cypress ||
    window._phantom ||
    window.__nightmare
  );
}
