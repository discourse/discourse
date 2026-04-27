import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

@disableImplicitInjections
export default class CanonicalUrlService extends Service {
  @tracked url = null;

  set(url) {
    this.url = url;
  }

  clear() {
    this.url = null;
  }
}
