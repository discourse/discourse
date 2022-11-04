import { getOwner } from "discourse-common/lib/get-owner";

export default {
  setupComponent(args, component) {
    const container = getOwner(this);
    const chatEmojiPickerManager = container.lookup(
      "service:chat-emoji-picker-manager"
    );

    component.set("chatEmojiPickerManager", chatEmojiPickerManager);
  },
};
