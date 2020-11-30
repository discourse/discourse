import Component from "@ember/component";
import { equal } from "@ember/object/computed";
export default Component.extend({
  classNames: ["user-stat"],
  type: "number",
  isNumber: equal("type", "number"),
  isDuration: equal("type", "duration"),
});
