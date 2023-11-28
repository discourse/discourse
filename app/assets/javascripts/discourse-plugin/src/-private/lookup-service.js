import { factory } from "ember-polaris-service";

export default function lookupService(name) {
  return factory((owner) => owner.lookup(`service:${name}`));
}
