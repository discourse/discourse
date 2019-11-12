import { equal } from "@ember/object/computed";
import Component from "@ember/component";
export default Component.extend({
  classNames: ["user-stat"],
  type: "number",
  isNumber: equal("type", "number"),
  isDuration: equal("type", "duration")
});
