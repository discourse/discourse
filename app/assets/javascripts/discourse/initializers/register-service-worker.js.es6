export default {
  name: "register-service-worker",

  initialize() {
    const isSecured =
      document.location.protocol === "https:" ||
      location.hostname === "localhost";

    const isSupported = isSecured && "serviceWorker" in navigator;

    if (isSupported) {
      const isSafari = /^((?!chrome|android).)*safari/i.test(
        navigator.userAgent
      );

      const disableServiceWorker = window.location.search.includes(
        "disable_service_worker"
      );

      if (Discourse.ServiceWorkerURL && !isSafari && !disableServiceWorker) {
        navigator.serviceWorker.getRegistrations().then(registrations => {
          for (let registration of registrations) {
            if (
              registration.active &&
              !registration.active.scriptURL.includes(
                Discourse.ServiceWorkerURL
              )
            ) {
              registration.unregister();
            }
          }
        });

        navigator.serviceWorker
          .register(`${Discourse.BaseUri}/${Discourse.ServiceWorkerURL}`)
          .catch(error => {
            Ember.Logger.info(`Failed to register Service Worker: ${error}`);
          });
      } else {
        navigator.serviceWorker.getRegistrations().then(registrations => {
          for (let registration of registrations) {
            registration.unregister();
          }
        });
      }
    }
  }
};
