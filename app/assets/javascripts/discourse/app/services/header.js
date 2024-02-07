import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

@disableImplicitInjections
export default class Header extends Service {
  @tracked topic = null;
  @tracked hamburgerVisible = false;
  @tracked userVisible = false;
}
