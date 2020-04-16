import FilterComponent from "admin/components/report-filters/filter";
import discourseComputed from "discourse-common/utils/decorators";

export default FilterComponent.extend({
  classNames: ["group-filter"],

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
