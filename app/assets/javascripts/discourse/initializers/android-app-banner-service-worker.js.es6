// Android Chrome App Banner requires at least **one** service worker to be instantiate and https.
// After Discourse starts to use service workers for other stuff (like mobile notification, offline mode, or ember)
// we can ditch this.

export default {
  name: 'android-app-banner-service-worker',

  initialize(container) {
    const caps = container.lookup('capabilities:main');
    const isSecure = document.location.protocol === 'https:';

    if (isSecure && caps.isAndroid && 'serviceWorker' in navigator) {
        navigator.serviceWorker.register(Discourse.BaseUri + '/service-worker.js', {scope: './'});
    }
  }
};
