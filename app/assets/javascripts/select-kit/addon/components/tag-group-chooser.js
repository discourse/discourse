import { computed } from "@ember/object";
import { service } from "@ember/service";
import { classNames } from "@ember-decorators/component";
import { bind } from "discourse/lib/decorators";
import { makeArray } from "discourse/lib/helpers";
import MultiSelectComponent from "select-kit/components/multi-select";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";
import TagChooserRow from "./tag-chooser-row";

@classNames("tag-group-chooser", "tag-chooser")
@selectKitOptions({
  allowAny: false,
  filterable: true,
  filterPlaceholder: "category.tag_groups_placeholder",
  limit: null,
})
@pluginApiIdentifiers("tag-group-chooser")
export default class TagGroupChooser extends MultiSelectComponent {
  @service tagUtils;

  modifyComponentForRow() {
    return TagChooserRow;
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

  validateCreate(filter, content) {
    return this.tagUtils.validateCreate(
      filter,
      content,
      this.selectKit.options.maximum,
      (e) => this.addError(e),
      this.termMatchesForbidden,
      (value) => this.getValue(value),
      this.value
    );
  }

  createContentFromInput(input) {
    return this.tagUtils.createContentFromInput(input);
  }

  search(query) {
    const data = {
      q: query,
      limit: this.siteSettings.max_tag_search_results,
    };

    return this.tagUtils
      .searchTags("/tag_groups/filter/search", data, this._transformJson)
      .then((results) => {
        if (results && results.length) {
          return results.filter((r) => {
            return !makeArray(this.tagGroups).includes(this.getValue(r));
          });
        }
      });
  }

  @bind
  _transformJson(json) {
    if (this.isDestroyed || this.isDestroying) {
      return [];
    }
    return json.results
      .sort((a, b) => a.name > b.name)
      .map((result) => {
        return { id: result.name, name: result.name, count: result.count };
      });
  }
}
