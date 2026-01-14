import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";

export default class ChatSearchQuery extends Service {
  @tracked query = "";
}
