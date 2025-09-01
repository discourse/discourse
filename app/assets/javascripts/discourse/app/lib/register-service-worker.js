import getAbsoluteURL, { isAbsoluteURL } from "discourse/lib/get-url";

export async function registerServiceWorker(
  serviceWorkerURL,
  registerOptions = {}
) {
  if (!(window.isSecureContext && "serviceWorker" in navigator)) {
    return false;
  }

  if (!serviceWorkerURL) {
    // Unregister everything.
    for (let registration of await navigator.serviceWorker.getRegistrations()) {
      unregister(registration);
    }

    return true;
  }

  for (let registration of await navigator.serviceWorker.getRegistrations()) {
    if (
      registration.active &&
      !registration.active.scriptURL.includes(serviceWorkerURL)
    ) {
      unregister(registration);
    }
  }

  // N.B: The promise returned by `register` may not actually be resolved in some classes
  // (e.g. if the worker is already registered)
  // https://stackoverflow.com/a/71240372
  navigator.serviceWorker
    .register(getAbsoluteURL(`/${serviceWorkerURL}`), registerOptions)
    .catch((err) => {
      console.log(`failed to register service worker: ${err}`);
    });

  const registration = await navigator.serviceWorker.ready;
  return registration !== undefined;
}

function unregister(registration) {
  if (isAbsoluteURL(registration.scope)) {
    registration.unregister();
  }
}
