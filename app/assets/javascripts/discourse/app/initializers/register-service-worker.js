import { isAbsoluteURL } from "discourse-common/lib/get-url";
import getAbsoluteURL from "discourse-common/lib/get-url";

export default {
  name: "register-service-worker",

  initialize() {
    const isSecured =
      document.location.protocol === "https:" ||
      location.hostname === "localhost";

    const isSupported = isSecured && "serviceWorker" in navigator;

    if (isSupported) {
      const caps = Discourse.__container__.lookup("capabilities:main");
      const isAppleBrowser =
        caps.isSafari ||
        (caps.isIOS &&
          !window.matchMedia("(display-mode: standalone)").matches);

      if (Discourse.ServiceWorkerURL && !isAppleBrowser) {
        navigator.serviceWorker.getRegistrations().then(registrations => {
          for (let registration of registrations) {
            if (
              registration.active &&
              !registration.active.scriptURL.includes(
                Discourse.ServiceWorkerURL
              )
            ) {
              this.unregister(registration);
            }
          }
        });

        navigator.serviceWorker
          .register(getAbsoluteURL(`/${Discourse.ServiceWorkerURL}`))
          .catch(error => {
            // eslint-disable-next-line no-console
            console.info(`Failed to register Service Worker: ${error}`);
          });
      } else {
        navigator.serviceWorker.getRegistrations().then(registrations => {
          for (let registration of registrations) {
            this.unregister(registration);
          }
        });
      }
    }
  },

  unregister(registration) {
    if (isAbsoluteURL(registration.scope)) {
      registration.unregister();
    }
  }
};
