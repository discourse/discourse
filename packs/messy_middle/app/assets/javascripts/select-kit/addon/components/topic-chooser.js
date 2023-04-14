import { isEmpty } from "@ember/utils";
import { searchForTerm } from "discourse/lib/search";
import ComboBoxComponent from "select-kit/components/combo-box";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["topic-chooser"],
  classNames: ["topic-chooser"],

  nameProperty: "fancy_title",
  labelProperty: "title",
  titleProperty: "title",

  selectKitOptions: {
    clearable: true,
    filterable: true,
    filterPlaceholder: "choose_topic.title.placeholder",
    additionalFilters: "",
  },

  modifyComponentForRow() {
    return "topic-row";
  },

  search(filter) {
    if (isEmpty(filter) && isEmpty(this.selectKit.options.additionalFilters)) {
      return [];
    }

    const searchParams = {};
    if (!isEmpty(filter)) {
      searchParams.typeFilter = "topic";
      searchParams.restrictToArchetype = "regular";
      searchParams.searchForId = true;
    }

    return searchForTerm(
      `${filter} ${this.selectKit.options.additionalFilters}`,
      searchParams
    ).then((results) => {
      if (results?.posts?.length > 0) {
        return results.posts.mapBy("topic");
      }
    });
  },
});
