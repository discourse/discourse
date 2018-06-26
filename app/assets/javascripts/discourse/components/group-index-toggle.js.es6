import { iconHTML } from "discourse-common/lib/icon-library";
import { bufferedRender } from "discourse-common/lib/buffered-render";

export default Ember.Component.extend(
  bufferedRender({
    tagName: "th",
    classNames: ["sortable"],
    rerenderTriggers: ["order", "desc"],

    buildBuffer(buffer) {
      buffer.push("<span class='header-contents'>");
      buffer.push(I18n.t(this.get("i18nKey")));

      if (this.get("field") === this.get("order")) {
        buffer.push(iconHTML(this.get("desc") ? "chevron-down" : "chevron-up"));
      }
      buffer.push("</span>");
    },

    click() {
      if (this.get("order") === this.field) {
        this.set("desc", this.get("desc") ? null : true);
      } else {
        this.setProperties({ order: this.field, desc: null });
      }
    }
  })
);
