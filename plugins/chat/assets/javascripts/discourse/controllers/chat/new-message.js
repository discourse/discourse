import Controller from "@ember/controller";

export default class ChatNewMessageController extends Controller {
  queryParams = ["recipients", "channel_id", "channel", "message"];
}
