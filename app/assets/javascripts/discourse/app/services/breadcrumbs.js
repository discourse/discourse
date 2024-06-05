import Service from "@ember/service";
import { TrackedSet } from "@ember-compat/tracked-built-ins";

export default class Breadcrumbs extends Service {
  containers = new TrackedSet();
  items = new TrackedSet();
}
