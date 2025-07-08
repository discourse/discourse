import MessageBus from "message-bus-client";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

@disableImplicitInjections
export default class MessageBusService {
  static isServiceFactory = true;

  static create() {
    // TODO - message-bus-client module not working properly?
    return window.MessageBus;
  }
}
