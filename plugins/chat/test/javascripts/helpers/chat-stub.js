import fabricators from "../helpers/fabricators";
import { isPresent } from "@ember/utils";
import Service from "@ember/service";

let publicChannels;
let userCanChat;

class ChatStub extends Service {
  userCanChat = userCanChat;
  publicChannels = publicChannels;
}

export function setup(context, options = {}) {
  context.registry.register("service:chat-stub", ChatStub);
  context.registry.injection("component", "chat", "service:chat-stub");

  publicChannels = isPresent(options.publicChannels)
    ? options.publicChannels
    : [fabricators.chatChannel()];
  userCanChat = isPresent(options.userCanChat) ? options.userCanChat : true;
}

export function teardown() {
  publicChannels = [];
  userCanChat = true;
}
