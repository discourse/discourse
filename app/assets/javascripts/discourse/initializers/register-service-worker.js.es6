export default {
  name: 'register-service-worker',

  initialize() {
    // only allow service worker on android for now
    if (!/(android)/i.test(navigator.userAgent)) {

      // remove old service worker
      if ('serviceWorker' in navigator && navigator.serviceWorker.getRegistrations) {
        navigator.serviceWorker.getRegistrations().then((registrations) => {
          for(let registration of registrations) {
            registration.unregister();
          };
        });
      }

    } else {

      const isSecure = (document.location.protocol === 'https:') ||
        (location.hostname === "localhost");


      if (isSecure && ('serviceWorker' in navigator)) {
        navigator.serviceWorker.register(`${Discourse.BaseUri}/service-worker.js`);
      }
    }
  }
};
