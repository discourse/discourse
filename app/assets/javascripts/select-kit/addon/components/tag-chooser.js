import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import { attributeBindings, classNames } from "@ember-decorators/component";
import { bind } from "discourse/lib/decorators";
import { makeArray } from "discourse/lib/helpers";
import MultiSelectComponent from "select-kit/components/multi-select";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";
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
})
@pluginApiIdentifiers("tag-chooser")
export default class TagChooser extends MultiSelectComponent {
  @service tagUtils;

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
    return makeArray(this.tags).uniq();
  }

  @computed("tags.[]")
  get content() {
    return makeArray(this.tags)
      .uniq()
      .map((t) => this.defaultItem(t, t));
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
    const selectedTags = makeArray(this.tags).filter(Boolean);

    const data = {
      q: query,
      limit: this.siteSettings.max_tag_search_results,
      categoryId: this.categoryId,
    };

    if (selectedTags.length || this.blockedTags.length) {
      data.selected_tags = selectedTags
        .concat(this.blockedTags)
        .uniq()
        .slice(0, 100);
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
        return !this.blockedTags.includes(result.id);
      });
    }

    if (this.siteSettings.tags_sort_alphabetically) {
      results = results.sort((a, b) => a.id > b.id);
    }

    return results.uniqBy("id");
  }
}
