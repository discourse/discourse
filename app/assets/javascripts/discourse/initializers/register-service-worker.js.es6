export default {
  name: "register-service-worker",

  initialize() {
    const isSecured =
      document.location.protocol === "https:" ||
      location.hostname === "localhost";

    const isSupported = isSecured && "serviceWorker" in navigator;

    if (isSupported) {
      const caps = Discourse.__container__.lookup("capabilities:main");
      const isApple = caps.isSafari || caps.isIOS || caps.isIpadOS;

      if (Discourse.ServiceWorkerURL && !isApple) {
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
          .register(`${Discourse.BaseUri}/${Discourse.ServiceWorkerURL}`)
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
    if (registration.scope.startsWith(Discourse.BaseUrl)) {
      registration.unregister();
    }
  }
};
