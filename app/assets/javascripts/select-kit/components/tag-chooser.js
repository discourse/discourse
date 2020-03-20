import { computed } from "@ember/object";
import MultiSelectComponent from "select-kit/components/multi-select";
import TagsMixin from "select-kit/mixins/tags";
import { makeArray } from "discourse-common/lib/helpers";

export default MultiSelectComponent.extend(TagsMixin, {
  pluginApiIdentifiers: ["tag-chooser"],
  classNames: ["tag-chooser"],

  selectKitOptions: {
    filterable: true,
    filterPlaceholder: "tagging.choose_for_topic",
    limit: null,
    allowAny: "canCreateTag",
    maximum: "maximumTagCount"
  },

  modifyComponentForRow() {
    return "tag-chooser-row";
  },

  blacklist: null,
  attributeBindings: ["categoryId"],
  excludeSynonyms: false,
  excludeHasSynonyms: false,

  canCreateTag: computed("site.can_create_tag", "allowCreate", function() {
    return this.allowCreate || this.site.can_create_tag;
  }),

  maximumTagCount: computed(
    "siteSettings.max_tags_per_topic",
    "unlimitedTagCount",
    function() {
      if (!this.unlimitedTagCount) {
        return parseInt(
          this.options.limit ||
            this.options.maximum ||
            this.get("siteSettings.max_tags_per_topic"),
          10
        );
      }

      return null;
    }
  ),

  init() {
    this._super(...arguments);

    this.setProperties({
      blacklist: this.blacklist || [],
      termMatchesForbidden: false,
      termMatchErrorMessage: null
    });
  },

  value: computed("tags.[]", function() {
    return makeArray(this.tags).uniq();
  }),

  content: computed("tags.[]", function() {
    return makeArray(this.tags)
      .uniq()
      .map(t => this.defaultItem(t, t));
  }),

  actions: {
    onChange(value) {
      this.set("tags", value);
    }
  },

  search(query) {
    const selectedTags = makeArray(this.tags).filter(Boolean);

    const data = {
      q: query,
      limit: this.get("siteSettings.max_tag_search_results"),
      categoryId: this.categoryId
    };

    if (selectedTags.length || this.blacklist.length) {
      data.selected_tags = selectedTags
        .concat(this.blacklist)
        .uniq()
        .slice(0, 100);
    }

    if (!this.everyTag) data.filterForInput = true;
    if (this.excludeSynonyms) data.excludeSynonyms = true;
    if (this.excludeHasSynonyms) data.excludeHasSynonyms = true;

    return this.searchTags("/tags/filter/search", data, this._transformJson);
  },

  _transformJson(context, json) {
    let results = json.results;

    context.setProperties({
      termMatchesForbidden: json.forbidden ? true : false,
      termMatchErrorMessage: json.forbidden_message
    });

    if (context.blacklist) {
      results = results.filter(result => {
        return !context.blacklist.includes(result.id);
      });
    }

    if (context.get("siteSettings.tags_sort_alphabetically")) {
      results = results.sort((a, b) => a.id > b.id);
    }

    return results.uniqBy("text").map(result => {
      return { id: result.text, name: result.text, count: result.count };
    });
  }
});
