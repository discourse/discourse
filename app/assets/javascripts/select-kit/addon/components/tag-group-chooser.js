import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { makeArray } from "discourse/lib/helpers";
import MultiSelectComponent from "select-kit/components/multi-select";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";
import TagsMixin from "select-kit/mixins/tags";

@classNames("tag-group-chooser", "tag-chooser")
@selectKitOptions({
  allowAny: false,
  filterable: true,
  filterPlaceholder: "category.tag_groups_placeholder",
  limit: null,
})
@pluginApiIdentifiers("tag-group-chooser")
export default class TagGroupChooser extends MultiSelectComponent.extend(
  TagsMixin
) {
  modifyComponentForRow() {
    return "tag-chooser-row";
  }

  @computed("tagGroups.[]")
  get value() {
    return makeArray(this.tagGroups).uniq();
  }

  @computed("tagGroups.[]")
  get content() {
    return makeArray(this.tagGroups)
      .uniq()
      .map((t) => this.defaultItem(t, t));
  }

  search(query) {
    const data = {
      q: query,
      limit: this.siteSettings.max_tag_search_results,
    };

    return this.searchTags(
      "/tag_groups/filter/search",
      data,
      this._transformJson
    ).then((results) => {
      if (results && results.length) {
        return results.filter((r) => {
          return !makeArray(this.tagGroups).includes(this.getValue(r));
        });
      }
    });
  }

  _transformJson(context, json) {
    return json.results
      .sort((a, b) => a.name > b.name)
      .map((result) => {
        return { id: result.name, name: result.name, count: result.count };
      });
  }
}
