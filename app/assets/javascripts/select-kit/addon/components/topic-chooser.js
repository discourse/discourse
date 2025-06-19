import { isEmpty } from "@ember/utils";
import { classNames } from "@ember-decorators/component";
import { searchForTerm } from "discourse/lib/search";
import ComboBoxComponent from "select-kit/components/combo-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";
import TopicRow from "./topic-row";

@classNames("topic-chooser")
@selectKitOptions({
  clearable: true,
  filterable: true,
  filterPlaceholder: "choose_topic.title.placeholder",
  additionalFilters: "",
})
@pluginApiIdentifiers("topic-chooser")
export default class TopicChooser extends ComboBoxComponent {
  nameProperty = "fancy_title";
  labelProperty = "title";
  titleProperty = "title";

  modifyComponentForRow() {
    return TopicRow;
  }

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
  }
}
