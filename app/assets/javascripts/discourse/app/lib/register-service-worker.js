import getAbsoluteURL, { isAbsoluteURL } from "discourse/lib/get-url";

export function registerServiceWorker(serviceWorkerURL, registerOptions = {}) {
  if (window.isSecureContext && "serviceWorker" in navigator) {
    if (serviceWorkerURL) {
      navigator.serviceWorker.getRegistrations().then((registrations) => {
        for (let registration of registrations) {
          if (
            registration.active &&
            !registration.active.scriptURL.includes(serviceWorkerURL)
          ) {
            unregister(registration);
          }
        }
      });

      navigator.serviceWorker
        .register(getAbsoluteURL(`/${serviceWorkerURL}`), registerOptions)
        .catch((error) => {
          // eslint-disable-next-line no-console
          console.info(`Failed to register Service Worker: ${error}`);
        });
    } else {
      navigator.serviceWorker.getRegistrations().then((registrations) => {
        for (let registration of registrations) {
          unregister(registration);
        }
      });
    }
  }
}

function unregister(registration) {
  if (isAbsoluteURL(registration.scope)) {
    registration.unregister();
  }
}
