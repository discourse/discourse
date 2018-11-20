import { iconHTML } from "discourse-common/lib/icon-library";
import { bufferedRender } from "discourse-common/lib/buffered-render";

export default Ember.Component.extend(
  bufferedRender({
    tagName: "th",
    classNames: ["sortable"],
    rerenderTriggers: ["order", "ascending"],

    buildBuffer(buffer) {
      const icon = this.get("icon");

      if (icon) {
        buffer.push(iconHTML(icon));
      }

      buffer.push(I18n.t(this.get("i18nKey")));

      if (this.get("field") === this.get("order")) {
        buffer.push(
          iconHTML(this.get("ascending") ? "chevron-up" : "chevron-down")
        );
      }
    },

    click() {
      const currentOrder = this.get("order");
      const field = this.get("field");

      if (currentOrder === field) {
        this.set("ascending", this.get("ascending") ? null : true);
      } else {
        this.setProperties({ order: field, ascending: null });
      }
    }
  })
);
