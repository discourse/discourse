import Component from "@ember/component";
import { iconHTML } from "discourse-common/lib/icon-library";
import { bufferedRender } from "discourse-common/lib/buffered-render";

export default Component.extend(
  bufferedRender({
    tagName: "th",
    classNames: ["sortable"],
    rerenderTriggers: ["order", "ascending"],

    buildBuffer(buffer) {
      const icon = this.icon;

      if (icon) {
        buffer.push(iconHTML(icon));
      }

      buffer.push(I18n.t(this.i18nKey));

      if (this.field === this.order) {
        buffer.push(iconHTML(this.ascending ? "chevron-up" : "chevron-down"));
      }
    },

    click() {
      const currentOrder = this.order;
      const field = this.field;

      if (currentOrder === field) {
        this.set("ascending", this.ascending ? null : true);
      } else {
        this.setProperties({ order: field, ascending: null });
      }
    }
  })
);
