import { gte } from "@ember/object/computed";
import Component from "@ember/component";
export default Component.extend({
  showUsername: gte("index", 1)
});
