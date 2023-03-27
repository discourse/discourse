import Controller from "@ember/controller";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

export default class ChatChannelController extends Controller {
  @service chat;

  @tracked targetMessageId = null;

  // Backwards-compatibility
  queryParams = ["messageId"];
}
