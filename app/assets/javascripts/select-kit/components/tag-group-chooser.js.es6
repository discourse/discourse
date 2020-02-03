import MultiSelectComponent from "select-kit/components/multi-select";
import TagsMixin from "select-kit/mixins/tags";
import { makeArray } from "discourse-common/lib/helpers";
import { computed } from "@ember/object";

export default MultiSelectComponent.extend(TagsMixin, {
  pluginApiIdentifiers: ["tag-group-chooser"],
  classNames: ["tag-group-chooser", "tag-chooser"],

  selectKitOptions: {
    allowAny: false,
    filterable: true,
    filterPlaceholder: "category.tag_groups_placeholder",
    limit: null
  },

  modifyComponentForRow() {
    return "tag-chooser-row";
  },

  value: computed("tagGroups.[]", function() {
    return makeArray(this.tagGroups).uniq();
  }),

  content: computed("tagGroups.[]", function() {
    return makeArray(this.tagGroups)
      .uniq()
      .map(t => this.defaultItem(t, t));
  }),

  actions: {
    onChange(value) {
      this.set("tagGroups", value);
    }
  },

  search(query) {
    const data = {
      q: query,
      limit: this.get("siteSettings.max_tag_search_results")
    };

    return this.searchTags(
      "/tag_groups/filter/search",
      data,
      this._transformJson
    ).then(results => {
      if (results && results.length) {
        return results.filter(r => {
          return !this.tagGroups.includes(this.getValue(r));
        });
      }
    });
  },

  _transformJson(context, json) {
    return json.results
      .sort((a, b) => a.id > b.id)
      .map(result => {
        return { id: result.text, name: result.text, count: result.count };
      });
  }
});
