import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import { attributeBindings, classNames } from "@ember-decorators/component";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import { bind } from "discourse/lib/decorators";
import { makeArray } from "discourse/lib/helpers";
import MultiSelectComponent from "discourse/select-kit/components/multi-select";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "discourse/select-kit/components/select-kit";
import SelectKitRow from "./select-kit/select-kit-row";
import TagChooserRow from "./tag-chooser-row";

@classNames("tag-chooser")
@attributeBindings("categoryId")
@selectKitOptions({
  filterable: true,
  filterPlaceholder: "tagging.choose_for_topic",
  limit: null,
  allowAny: "canCreateTag",
  maximum: "maximumTagCount",
  valueProperty: "id",
})
@pluginApiIdentifiers("tag-chooser")
export default class TagChooser extends MultiSelectComponent {
  @service tagUtils;

  valueProperty = "id";
  nameProperty = "name";

  blockedTags = null;
  excludeSynonyms = false;
  excludeHasSynonyms = false;

  init() {
    super.init(...arguments);

    this.setProperties({
      blockedTags: this.blockedTags || [],
      termMatchesForbidden: false,
      termMatchErrorMessage: null,
    });
  }

  modifyComponentForRow(collection, item) {
    if (this.getValue(item) === this.selectKit.filter && !item.count) {
      return SelectKitRow;
    }

    return TagChooserRow;
  }

  @computed("site.can_create_tag", "allowCreate")
  get canCreateTag() {
    return this.allowCreate && this.site.can_create_tag;
  }

  @computed("siteSettings.max_tags_per_topic", "unlimitedTagCount")
  get maximumTagCount() {
    if (!this.unlimitedTagCount) {
      return parseInt(
        this.options.limit ||
          this.options.maximum ||
          this.siteSettings.max_tags_per_topic,
        10
      );
    }

    return null;
  }

  @computed("tags.[]")
  get value() {
    return uniqueItemsFromArray(
      makeArray(this.tags).map((t) => (typeof t === "string" ? t : t.id))
    );
  }

  @computed("tags.[]")
  get content() {
    return uniqueItemsFromArray(
      makeArray(this.tags).map((t) => {
        if (typeof t === "string") {
          return this.defaultItem(t, t);
        }
        return this.defaultItem(t.id, t.name);
      })
    );
  }

  @action
  _onChange(value, items) {
    if (this.onChange) {
      this.onChange(value, items);
    } else {
      this.set("tags", value);
    }
  }

  validateCreate(filter, content) {
    // Get tag names for validation (not IDs)
    const selectedTagNames = makeArray(this.tags)
      .filter(Boolean)
      .map((t) => (typeof t === "string" ? t : t.name));

    return this.tagUtils.validateCreate(
      filter,
      content,
      this.selectKit.options.maximum,
      (e) => this.addError(e),
      this.termMatchesForbidden,
      (value) => this.getValue(value),
      selectedTagNames
    );
  }

  createContentFromInput(input) {
    return this.tagUtils.createContentFromInput(input);
  }

  search(query) {
    const selectedTags = makeArray(this.tags).filter(Boolean);

    const data = {
      q: query,
      limit: this.siteSettings.max_tag_search_results,
      categoryId: this.categoryId,
    };

    if (selectedTags.length || this.blockedTags.length) {
      const allTags = uniqueItemsFromArray(
        selectedTags.concat(this.blockedTags)
      ).slice(0, 100);

      // Extract IDs for objects, keep strings for legacy/blocked tags
      const ids = allTags
        .map((t) => (typeof t === "string" ? null : t.id))
        .filter((id) => id !== null);
      const names = allTags.filter((t) => typeof t === "string");

      if (ids.length) {
        data.selected_tag_ids = ids;
      }
      if (names.length) {
        data.selected_tags = names;
      }
    }

    if (!this.everyTag) {
      data.filterForInput = true;
    }
    if (this.excludeSynonyms) {
      data.excludeSynonyms = true;
    }
    if (this.excludeHasSynonyms) {
      data.excludeHasSynonyms = true;
    }

    return this.tagUtils.searchTags(
      "/tags/filter/search",
      data,
      this._transformJson
    );
  }

  @bind
  _transformJson(json) {
    if (this.isDestroyed || this.isDestroying) {
      return [];
    }

    let results = json.results;

    this.setProperties({
      termMatchesForbidden: json.forbidden ? true : false,
      termMatchErrorMessage: json.forbidden_message,
    });

    if (this.blockedTags) {
      results = results.filter((result) => {
        return !this.blockedTags.includes(result.name);
      });
    }

    if (this.siteSettings.tags_sort_alphabetically) {
      results = results.sort((a, b) => a.name > b.name);
    }

    return uniqueItemsFromArray(results, "name");
  }
}
