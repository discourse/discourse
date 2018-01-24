function deRegister() {
  if (navigator.serviceWorker.getRegistrations) {
    navigator.serviceWorker.getRegistrations().then(r => {
      r.forEach(reg => {
        if (reg.active && reg.active.scriptURL.indexOf('service-worker.js') > 0) {
          reg.unregister();
        }
      });
    });
  }
}

export default {
  name: 'register-service-worker',

  initialize(container) {
    const siteSettings = container.lookup('site-settings:main');
    const isSecure = (document.location.protocol === 'https:') ||
      (location.hostname === "localhost");

    if (isSecure && ('serviceWorker' in navigator)) {

      let agents = siteSettings.service_worker_user_agents.split('|');

      let allowed = false;

      if (agents[0].length > 0) {
        const userAgent = (navigator.userAgent || "unknown").toLowerCase();
        for(let i=0; i<agents.length; i++) {
          allowed = userAgent.indexOf(agents[i]) !== -1;
          if (allowed) { break; }
        }
      }

      if (allowed) {
        // TODO no need to register if we already registered recently
        // consider using local storage to figure out when last registered
        navigator.serviceWorker.register(`${Discourse.BaseUri}/service-worker.js`);
      } else {
        deRegister();
      }
    }
  }
};
