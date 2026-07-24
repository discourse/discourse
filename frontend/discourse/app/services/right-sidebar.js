import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";

export default class RightSidebarService extends Service {
  @tracked isOpen = false;
}
