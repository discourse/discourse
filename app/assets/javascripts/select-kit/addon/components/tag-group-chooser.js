import MultiSelectComponent from "select-kit/components/multi-select";
import TagsMixin from "select-kit/mixins/tags";
import { computed } from "@ember/object";
import { makeArray } from "discourse-common/lib/helpers";

export default MultiSelectComponent.extend(TagsMixin, {
  pluginApiIdentifiers: ["tag-group-chooser"],
  classNames: ["tag-group-chooser", "tag-chooser"],

  selectKitOptions: {
    allowAny: false,
    filterable: true,
    filterPlaceholder: "category.tag_groups_placeholder",
    limit: null,
  },

  modifyComponentForRow() {
    return "tag-chooser-row";
  },

  value: computed("tagGroups.[]", function () {
    return makeArray(this.tagGroups).uniq();
  }),

  content: computed("tagGroups.[]", function () {
    return makeArray(this.tagGroups)
      .uniq()
      .map((t) => this.defaultItem(t, t));
  }),

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
  },

  _transformJson(context, json) {
    return json.results
      .sort((a, b) => a.name > b.name)
      .map((result) => {
        return { id: result.name, name: result.name, count: result.count };
      });
  },
});
