import Component from "@ember/component";
import { iconHTML } from "discourse-common/lib/icon-library";
import { bufferedRender } from "discourse-common/lib/buffered-render";

export default Component.extend(
  bufferedRender({
    tagName: "th",
    classNames: ["sortable"],
    rerenderTriggers: ["order", "desc"],

    buildBuffer(buffer) {
      buffer.push("<span class='header-contents'>");
      buffer.push(I18n.t(this.i18nKey));

      if (this.field === this.order) {
        buffer.push(iconHTML(this.desc ? "chevron-down" : "chevron-up"));
      }
      buffer.push("</span>");
    },

    click() {
      if (this.order === this.field) {
        this.set("desc", this.desc ? null : true);
      } else {
        this.setProperties({ order: this.field, desc: null });
      }
    }
  })
);
