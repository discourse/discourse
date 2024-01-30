import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export default Component.extend({
  tagName: "",

  @discourseComputed("type")
  label(type) {
    return I18n.t(`groups.manage.logs.${type}`);
  },

  @discourseComputed("value", "type")
  filterText(value, type) {
    return type === "action"
      ? I18n.t(`group_histories.actions.${value}`)
      : value;
  },
});
