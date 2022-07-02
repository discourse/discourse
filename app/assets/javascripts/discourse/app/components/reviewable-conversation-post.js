import Component from "@ember/component";
import { gte } from "@ember/object/computed";
export default Component.extend({
  tagName: "",
  showUsername: gte("index", 1)
});
