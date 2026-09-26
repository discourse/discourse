import { lookup } from "discourse/lib/service";
import { registerServiceWorker } from "discourse/lib/register-service-worker";
import SessionService from "discourse/services/session";

export default {
  initialize(owner) {
    let { serviceWorkerURL } = lookup(owner, SessionService);
    registerServiceWorker(serviceWorkerURL);
  },
};
