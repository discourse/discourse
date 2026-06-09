import "message-bus-client";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

@disableImplicitInjections
export default class MessageBusService {
  static isServiceFactory = true;

  static create() {
    return window.MessageBus;
  }
}
