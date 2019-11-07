import discourseComputed from "discourse-common/utils/decorators";
import { debounce } from "@ember/runloop";
import Controller from "@ember/controller";

const { get } = Ember;

export default Controller.extend({
  filter: null,

  @discourseComputed("model.[]", "filter")
  filterReports(reports, filter) {
    if (filter) {
      filter = filter.toLowerCase();
      return reports.filter(report => {
        return (
          (get(report, "title") || "").toLowerCase().indexOf(filter) > -1 ||
          (get(report, "description") || "").toLowerCase().indexOf(filter) > -1
        );
      });
    }
    return reports;
  },

  actions: {
    filterReports(filter) {
      debounce(this, this._performFiltering, filter, 250);
    }
  },

  _performFiltering(filter) {
    this.set("filter", filter);
  }
});
