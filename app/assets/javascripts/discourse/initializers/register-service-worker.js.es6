export default {
  name: 'register-service-worker',

  initialize() {
    const isSecured = (document.location.protocol === 'https:') ||
          (location.hostname === "localhost");

    const isSupported= isSecured && ('serviceWorker' in navigator);
    const isSafari = /^((?!chrome|android).)*safari/i.test(navigator.userAgent);
    const isAndroid = navigator.userAgent.indexOf('Android') !== -1;

    if (isSupported) {
      if (Discourse.ServiceWorkerURL && !isSafari && isAndroid) {
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
  }
};
