export default {
  name: 'register-service-worker',

  initialize() {
    const isSecure = (document.location.protocol === 'https:') ||
      (location.hostname === "localhost");

    if (isSecure && ('serviceWorker' in navigator)) {
      navigator.serviceWorker.register(`${Discourse.BaseUri}/service-worker.js`);
    }
  }
};
