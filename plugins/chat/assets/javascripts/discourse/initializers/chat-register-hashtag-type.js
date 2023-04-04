import { withPluginApi } from "discourse/lib/plugin-api";
import ChannelHashtagType from "discourse/plugins/chat/discourse/lib/hashtag-types/channel";

export default {
  name: "chat-register-hashtag-type",
  after: "register-hashtag-types",
  before: "hashtag-css-generator",

  initialize() {
    withPluginApi("0.8.7", (api) => {
      api.registerHashtagType("channel", ChannelHashtagType);
    });
  },
};
