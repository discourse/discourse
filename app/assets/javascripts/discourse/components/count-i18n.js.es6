import Component from "@ember/component";
import { bufferedRender } from "discourse-common/lib/buffered-render";

export default Component.extend(
  bufferedRender({
    tagName: "span",
    rerenderTriggers: ["count", "suffix"],

    buildBuffer(buffer) {
      buffer.push(
        I18n.t(this.key + (this.suffix || ""), {
          count: this.count
        })
      );
    }
  })
);
