import { registerServiceWorker } from "discourse/lib/register-service-worker";

export default {
  name: "register-service-worker",

  initialize(container) {
    let { serviceWorkerURL } = container.lookup("service:session");
    registerServiceWorker(container, serviceWorkerURL);
  },
};
