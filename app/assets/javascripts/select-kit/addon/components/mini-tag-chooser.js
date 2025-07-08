import { computed } from "@ember/object";
import { empty, or } from "@ember/object/computed";
import { service } from "@ember/service";
import {
  attributeBindings,
  classNameBindings,
  classNames,
} from "@ember-decorators/component";
import { setting } from "discourse/lib/computed";
import { bind } from "discourse/lib/decorators";
import { makeArray } from "discourse/lib/helpers";
import { i18n } from "discourse-i18n";
import MultiSelectComponent from "select-kit/components/multi-select";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";
import SelectKitRow from "./select-kit/select-kit-row";
import TagRow from "./tag-row";

@attributeBindings("selectKit.options.categoryId:category-id")
@classNames("mini-tag-chooser")
@classNameBindings("noTags")
@selectKitOptions({
  allowAny: "allowAnyTag",
  fullWidthOnMobile: true,
  filterable: true,
  caretDownIcon: "caretIcon",
  caretUpIcon: "caretIcon",
  termMatchesForbidden: false,
  categoryId: null,
  everyTag: false,
  closeOnChange: false,
  maximum: "maxTagsPerTopic",
  autoInsertNoneItem: false,
  useHeaderFilter: false,
})
@pluginApiIdentifiers(["mini-tag-chooser"])
export default class MiniTagChooser extends MultiSelectComponent {
  @service tagUtils;

  @empty("value") noTags;
  @or("allowCreate", "site.can_create_tag") allowAnyTag;

  @setting("max_tag_search_results") maxTagSearchResults;
  @setting("max_tags_per_topic") maxTagsPerTopic;

  modifyComponentForRow(collection, item) {
    if (this.getValue(item) === this.selectKit.filter && !item.count) {
      return SelectKitRow;
    }

    return TagRow;
  }

  modifyNoSelection() {
    if (this.selectKit.options.minimum > 0) {
      return this.defaultItem(
        null,
        i18n("tagging.choose_for_topic_required", {
          count: this.selectKit.options.minimum,
        })
      );
    } else {
      return this.defaultItem(null, i18n("tagging.choose_for_topic"));
    }
  }

  @computed("value.[]", "content.[]")
  get caretIcon() {
    const maximum = this.selectKit.options.maximum;
    return maximum && makeArray(this.value).length >= parseInt(maximum, 10)
      ? null
      : "plus";
  }

  @computed("value.[]")
  get content() {
    let values = makeArray(this.value);
    if (this.selectKit.options.hiddenValues) {
      values = values.filter(
        (val) => !this.selectKit.options.hiddenValues.includes(val)
      );
    }
    return values.map((x) => this.defaultItem(x, x));
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

  search(filter) {
    const maximum = this.selectKit.options.maximum;
    if (maximum === 0) {
      const key = "select_kit.max_content_reached";
      this.addError(i18n(key, { count: maximum }));
      return [];
    }

    const data = {
      q: filter || "",
      limit: this.maxTagSearchResults,
      categoryId: this.selectKit.options.categoryId,
    };

    if (this.value) {
      data.selected_tags = this.value.slice(0, 100);
    }

    if (!this.selectKit.options.everyTag) {
      data.filterForInput = true;
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

    if (this.siteSettings.tags_sort_alphabetically) {
      results = results.sort((a, b) => a.text.localeCompare(b.text));
    }

    if (json.required_tag_group) {
      this.set(
        "selectKit.options.translatedFilterPlaceholder",
        i18n("tagging.choose_for_topic_required_group", {
          count: json.required_tag_group.min_count,
          name: json.required_tag_group.name,
        })
      );
    } else {
      this.set("selectKit.options.translatedFilterPlaceholder", null);
    }

    return results.filter((r) => !makeArray(this.tags).includes(r.id));
  }
}
