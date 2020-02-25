import { computed } from "@ember/object";
import Component from "@ember/component";

export default Component.extend({
  tokenSeparator: "|",

  nameProperty: "name",
  valueProperty: "id",

  groupChoices: computed("site.groups", function() {
    return (this.site.groups || []).map(g => {
      return { name: g.name, id: g.id.toString() };
    });
  }),

  settingValue: computed("value", function() {
    return (this.value || "").split(this.tokenSeparator).filter(Boolean);
  }),

  actions: {
    onChangeGroupListSetting(value) {
      this.set("value", value.join(this.tokenSeparator));
    }
  }
});
