import { bufferedRender } from "discourse-common/lib/buffered-render";
import { iconHTML } from "discourse-common/lib/icon-library";

export default Ember.Component.extend(
  bufferedRender({
    classNameBindings: [":tip", "good", "bad"],
    rerenderTriggers: ["validation"],

    bad: Em.computed.alias("validation.failed"),
    good: Em.computed.not("bad"),

    buildBuffer(buffer) {
      const reason = this.get("validation.reason");
      if (reason) {
        buffer.push(
          iconHTML(this.get("good") ? "check" : "times") + " " + reason
        );
      }
    }
  })
);
