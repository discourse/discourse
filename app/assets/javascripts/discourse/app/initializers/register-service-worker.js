import getAbsoluteURL, { isAbsoluteURL } from "discourse-common/lib/get-url";

export default {
  name: "register-service-worker",

  initialize(container) {
    const isSecured = document.location.protocol === "https:";

    if (isSecured && "serviceWorker" in navigator) {
      let { serviceWorkerURL } = container.lookup("session:main");
      const caps = container.lookup("capabilities:main");
      const isAppleBrowser =
        caps.isSafari ||
        (caps.isIOS &&
          !window.matchMedia("(display-mode: standalone)").matches);

      if (serviceWorkerURL && !isAppleBrowser) {
        navigator.serviceWorker.getRegistrations().then((registrations) => {
          for (let registration of registrations) {
            if (
              registration.active &&
              !registration.active.scriptURL.includes(serviceWorkerURL)
            ) {
              this.unregister(registration);
            }
          }
        });

        navigator.serviceWorker
          .register(getAbsoluteURL(`/${serviceWorkerURL}`))
          .catch((error) => {
            // eslint-disable-next-line no-console
            console.info(`Failed to register Service Worker: ${error}`);
          });
      } else {
        navigator.serviceWorker.getRegistrations().then((registrations) => {
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
  },
};
