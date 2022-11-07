import fabricators from "../helpers/fabricators";
import { isPresent } from "@ember/utils";
import Service from "@ember/service";

let publicChannels;
let userCanChat;
let fullScreenChatOpen;

class ChatStub extends Service {
  userCanChat = userCanChat;
  publicChannels = publicChannels;
  fullScreenChatOpen = fullScreenChatOpen;
}

export function setup(context, options = {}) {
  context.registry.register("service:chat-stub", ChatStub);
  context.registry.injection("component", "chat", "service:chat-stub");

  publicChannels = isPresent(options.publicChannels)
    ? options.publicChannels
    : [fabricators.chatChannel()];
  userCanChat = isPresent(options.userCanChat) ? options.userCanChat : true;
  fullScreenChatOpen = isPresent(options.fullScreenChatOpen)
    ? options.fullScreenChatOpen
    : false;
}

export function teardown() {
  publicChannels = [];
  userCanChat = true;
  fullScreenChatOpen = false;
}
