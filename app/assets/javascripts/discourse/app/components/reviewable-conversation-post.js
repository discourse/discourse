import Component from "@ember/component";
import { gte } from "@ember/object/computed";
export default Component.extend({
  showUsername: gte("index", 1),
});
