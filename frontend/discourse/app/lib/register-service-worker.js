import getAbsoluteURL, { isAbsoluteURL } from "discourse/lib/get-url";

/** @type {ServiceWorkerRegistration | null} */
let registration = null;

/** @returns {ServiceWorkerRegistration | null} */
export function getServiceWorkerRegistration() {
  return registration;
}

export async function registerServiceWorker(
  serviceWorkerURL,
  registerOptions = {}
) {
  if (!(window.isSecureContext && "serviceWorker" in navigator)) {
    return false;
  }

  if (!serviceWorkerURL) {
    // Unregister everything.
    for (let reg of await navigator.serviceWorker.getRegistrations()) {
      unregister(reg);
    }

    return true;
  }

  for (let reg of await navigator.serviceWorker.getRegistrations()) {
    if (reg.active && !reg.active.scriptURL.includes(serviceWorkerURL)) {
      unregister(reg);
    }
  }

  // N.B: The promise returned by `register` may not actually be resolved in some cases
  // (e.g. if the worker is already registered)
  // https://stackoverflow.com/a/71240372
  navigator.serviceWorker
    .register(getAbsoluteURL(`/${serviceWorkerURL}`), registerOptions)
    .catch((err) => {
      // eslint-disable-next-line no-console
      console.log(`failed to register service worker: ${err}`);
    });

  registration = await navigator.serviceWorker.ready;
  return registration !== undefined;
}

function unregister(r) {
  if (isAbsoluteURL(r.scope)) {
    r.unregister();
  }
}
