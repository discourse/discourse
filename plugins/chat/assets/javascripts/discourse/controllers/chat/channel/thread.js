import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";

export default class ChatChannelThreadController extends Controller {
  @tracked targetMessageId = null;
}
