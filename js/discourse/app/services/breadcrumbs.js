import Service from "@ember/service";
import { DeferredTrackedSet } from "discourse/lib/tracked-tools";

export default class Breadcrumbs extends Service {
  containers = new DeferredTrackedSet();
  items = new DeferredTrackedSet();
}
