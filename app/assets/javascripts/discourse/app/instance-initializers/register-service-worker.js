import { registerServiceWorker } from "discourse/lib/register-service-worker";

export default {
  initialize(owner) {
    let { serviceWorkerURL } = owner.lookup("service:session");
    registerServiceWorker(serviceWorkerURL);
  },
};
