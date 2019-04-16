import FilterComponent from "admin/components/report-filters/filter";
import { default as computed } from "ember-addons/ember-computed-decorators";

export default FilterComponent.extend({
  classNames: ["group-filter"],

  layoutName: "admin/templates/components/report-filters/group",

  @computed()
  groupOptions() {
    return (this.site.groups || []).map(group => {
      return { name: group["name"], value: group["id"] };
    });
  },

  @computed("filter.default")
  groupId(filterDefault) {
    return filterDefault ? parseInt(filterDefault, 10) : null;
  }
});
