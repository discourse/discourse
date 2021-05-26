import Group from "discourse/models/group";
import SingleSelectComponent from "select-kit/components/single-select";

export default SingleSelectComponent.extend({
  pluginApiIdentifiers: ["user-group-filter"],
  classNames: ["user-group-filter"],

  selectKitOptions: {
    valueProperty: null,
    nameProperty: null,
    headerComponent: "user-group-filter/user-group-filter-header",
  },

  search(term) {
    return Group.findAll({
      term: term ? term : this.selectKit.options.filterValue,
      ignore_automatic: false,
    });
  },
});
