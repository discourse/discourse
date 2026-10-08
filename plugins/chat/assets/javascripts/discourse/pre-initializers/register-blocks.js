import { withPluginApi } from "discourse/lib/plugin-api";
import ChatChannelCardBlock from "../blocks/channel-card";
import FeaturedChatChannelsBlock from "../blocks/featured-channels";

export default {
  name: "chat:register-blocks",
  before: "freeze-block-registry",

  initialize() {
    withPluginApi((api) => {
      api.registerBlock(ChatChannelCardBlock);
      api.registerBlock(FeaturedChatChannelsBlock);
    });
  },
};
