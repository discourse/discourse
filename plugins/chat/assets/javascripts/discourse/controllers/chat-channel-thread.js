import Controller from "@ember/controller";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

export default class ChatChannelThreadController extends Controller {
  @service chat;

  @tracked targetMessageId = null;
}
