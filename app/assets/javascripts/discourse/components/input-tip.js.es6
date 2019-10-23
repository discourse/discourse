import Component from "@ember/component";
import { bufferedRender } from "discourse-common/lib/buffered-render";
import { iconHTML } from "discourse-common/lib/icon-library";

export default Component.extend(
  bufferedRender({
    classNameBindings: [":tip", "good", "bad"],
    rerenderTriggers: ["validation"],

    bad: Ember.computed.alias("validation.failed"),
    good: Ember.computed.not("bad"),

    buildBuffer(buffer) {
      const reason = this.get("validation.reason");
      if (reason) {
        buffer.push(iconHTML(this.good ? "check" : "times") + " " + reason);
      }
    }
  })
);
