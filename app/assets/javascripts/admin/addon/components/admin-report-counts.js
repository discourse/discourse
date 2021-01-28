import Component from "@ember/component";
import { match } from "@ember/object/computed";
export default Component.extend({
  allTime: true,
  tagName: "tr",
  reverseColors: match(
    "report.type",
    /^(time_to_first_response|topics_with_no_response)$/
  ),
  classNameBindings: ["reverseColors"],
});
