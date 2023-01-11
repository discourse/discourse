import MessageBus from "message-bus-client";

export default class MessageBusService {
  static isServiceFactory = true;

  static create() {
    return MessageBus;
  }
}
