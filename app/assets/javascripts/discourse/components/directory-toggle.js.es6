import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { iconHTML } from "discourse-common/lib/icon-library";
import { bufferedRender } from "discourse-common/lib/buffered-render";

export default Component.extend(
  bufferedRender({
    tagName: "th",
    classNames: ["sortable"],
    attributeBindings: ["title"],
    rerenderTriggers: ["order", "asc"],
    labelKey: null,

    @discourseComputed("field", "labelKey")
    title(field, labelKey) {
      if (!labelKey) {
        labelKey = `directory.${this.field}`;
      }

      return I18n.t(labelKey + "_long", { defaultValue: I18n.t(labelKey) });
    },

    buildBuffer(buffer) {
      const icon = this.icon;
      if (icon) {
        buffer.push(iconHTML(icon));
      }

      const field = this.field;
      buffer.push(I18n.t(this.labelKey || `directory.${field}`));

      if (field === this.order) {
        buffer.push(iconHTML(this.asc ? "chevron-up" : "chevron-down"));
      }
    },

    click() {
      const currentOrder = this.order,
        field = this.field;

      if (currentOrder === field) {
        this.set("asc", this.asc ? null : true);
      } else {
        this.setProperties({ order: field, asc: null });
      }
    }
  })
);
