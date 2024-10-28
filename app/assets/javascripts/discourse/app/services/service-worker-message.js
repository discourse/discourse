import { capabilities } from "discourse/services/capabilities";

export function isPrimaryTab() {
  return new Promise((resolve) => {
    if (capabilities.supportsServiceWorker) {
      navigator.serviceWorker.addEventListener("message", (event) => {
        resolve(event.data.primaryTab);
      });

      navigator.serviceWorker.ready.then((registration) => {
        registration.active.postMessage({ action: "primaryTab" });
      });
    } else {
      resolve(true);
    }
  });
}
