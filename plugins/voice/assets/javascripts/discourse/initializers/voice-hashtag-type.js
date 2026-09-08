import { withPluginApi } from "discourse/lib/plugin-api";
import RoomHashtagType from "../lib/hashtag-types/room";

export default {
  name: "voice-hashtag-type",
  before: "hashtag-css-generator",

  initialize(owner) {
    withPluginApi((api) => {
      api.registerHashtagType("room", new RoomHashtagType(owner));
    });
  },
};
