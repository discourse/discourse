import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { service } from "@ember/service";

export default class ChatChannelController extends Controller {
  @service chat;

  @tracked targetMessageId = null;

  // Backwards-compatibility
  queryParams = ["messageId"];
}
