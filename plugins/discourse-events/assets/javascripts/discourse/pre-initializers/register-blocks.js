import { withPluginApi } from "discourse/lib/plugin-api";
import UpcomingEventsBlock from "../blocks/upcoming-events";

export default {
  name: "discourse-events:register-blocks",
  before: "freeze-block-registry",

  initialize() {
    withPluginApi((api) => {
      api.registerBlock(UpcomingEventsBlock);
    });
  },
};
