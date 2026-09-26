import { factory } from "ember-polaris-service";

// Registered by the inject-discourse-objects initializer.
export default factory((owner) => owner.lookup("service:site"));
