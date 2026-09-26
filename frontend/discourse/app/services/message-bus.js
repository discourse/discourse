import "message-bus-client";
import { disableImplicitInjections } from "discourse/lib/disable-implicit-injections";
import { serviceFactory } from "discourse/lib/service";

@disableImplicitInjections
export default class MessageBusService {
  static isServiceFactory = true;

  static build() {
    return window.MessageBus;
  }
}

serviceFactory(MessageBusService);
