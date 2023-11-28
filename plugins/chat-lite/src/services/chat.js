import Service from "discourse-plugin/services";

export default class ChatService extends Service {
  get userCanChat() {
    return true;
  }
}
