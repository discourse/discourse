import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";

export default class ChatChannelController extends Controller {
  @tracked targetMessageId = null;

  // Backwards-compatibility
  queryParams = ["messageId"];
}
