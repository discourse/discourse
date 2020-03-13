import FilterComponent from "admin/components/report-filters/filter";
import discourseComputed from "discourse-common/utils/decorators";

export default FilterComponent.extend({
  classNames: ["group-filter"],

  layoutName: "admin/templates/components/report-filters/group",

  @discourseComputed()
  groupOptions() {
    return (this.site.groups || []).map(group => {
      return { name: group["name"], value: group["id"] };
    });
  },

  @discourseComputed("filter.default")
  groupId(filterDefault) {
    return filterDefault ? parseInt(filterDefault, 10) : null;
  }
});
