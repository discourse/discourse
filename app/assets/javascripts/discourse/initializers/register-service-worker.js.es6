export default {
  name: 'register-service-worker',

  initialize() {
    window.addEventListener('load', () => {
      const isSecured = (document.location.protocol === 'https:') ||
        (location.hostname === "localhost");

      const isSupported= isSecured && ('serviceWorker' in navigator);

      if (isSupported) {
        if (Discourse.ServiceWorkerURL) {
          navigator.serviceWorker
            .register(`${Discourse.BaseUri}/${Discourse.ServiceWorkerURL}`)
            .catch(error => {
              Ember.Logger.info(`Failed to register Service Worker: ${error}`);
            });
        } else {
          navigator.serviceWorker.getRegistrations().then(registrations => {
            for(let registration of registrations) {
              registration.unregister();
            };
          });
        }
      }
    });
  }
};
