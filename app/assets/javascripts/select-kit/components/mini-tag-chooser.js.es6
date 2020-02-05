import { empty, or } from "@ember/object/computed";
import ComboBox from "select-kit/components/combo-box";
import TagsMixin from "select-kit/mixins/tags";
import { makeArray } from "discourse-common/lib/helpers";
import { computed } from "@ember/object";
import { setting } from "discourse/lib/computed";

const SELECTED_TAGS_COLLECTION = "MINI_TAG_CHOOSER_SELECTED_TAGS";
import { ERRORS_COLLECTION } from "select-kit/components/select-kit";

export default ComboBox.extend(TagsMixin, {
  headerComponent: "mini-tag-chooser/mini-tag-chooser-header",
  pluginApiIdentifiers: ["mini-tag-chooser"],
  attributeBindings: ["selectKit.options.categoryId:category-id"],
  classNames: ["mini-tag-chooser"],
  classNameBindings: ["noTags"],
  noTags: empty("value"),
  maxTagSearchResults: setting("max_tag_search_results"),
  maxTagsPerTopic: setting("max_tags_per_topic"),
  highlightedTag: null,

  collections: computed(
    "mainCollection.[]",
    "errorsCollection.[]",
    "highlightedTag",
    function() {
      return this._super(...arguments);
    }
  ),

  selectKitOptions: {
    fullWidthOnMobile: true,
    filterable: true,
    caretDownIcon: "caretIcon",
    caretUpIcon: "caretIcon",
    termMatchesForbidden: false,
    categoryId: null,
    everyTag: false,
    none: "tagging.choose_for_topic",
    closeOnChange: false,
    maximum: 10,
    autoInsertNoneItem: false
  },

  modifyComponentForRow(collection, item) {
    if (this.getValue(item) === this.selectKit.filter) {
      return "select-kit/select-kit-row";
    }

    return "tag-row";
  },

  modifyComponentForCollection(collection) {
    if (collection === SELECTED_TAGS_COLLECTION) {
      return "mini-tag-chooser/selected-collection";
    }
  },

  modifyContentForCollection(collection) {
    if (collection === SELECTED_TAGS_COLLECTION) {
      return {
        selectedTags: this.value,
        highlightedTag: this.highlightedTag
      };
    }
  },

  allowAnyTag: or("allowCreate", "site.can_create_tag"),

  maximumSelectedTags: computed(function() {
    return parseInt(
      this.options.limit ||
        this.selectKit.options.maximum ||
        this.maxTagsPerTopic,
      10
    );
  }),

  init() {
    this._super(...arguments);

    this.insertAfterCollection(ERRORS_COLLECTION, SELECTED_TAGS_COLLECTION);
  },

  caretIcon: computed("value.[]", function() {
    const maximum = this.selectKit.options.maximum;
    return maximum && makeArray(this.value).length >= parseInt(maximum, 10)
      ? null
      : "plus";
  }),

  modifySelection(content) {
    let joinedTags = makeArray(this.value).join(", ");

    const minimum = this.selectKit.options.minimum;
    if (minimum && makeArray(this.value).length < parseInt(minimum, 10)) {
      const key =
        this.selectKit.options.minimumLabel ||
        "select_kit.min_content_not_reached";
      const label = I18n.t(key, { count: this.selectKit.options.minimum });
      content.title = content.name = content.label = label;
    } else {
      content.title = content.name = content.value = content.label = joinedTags;

      if (content.label.length > 32) {
        content.label = `${content.label.slice(0, 32)}...`;
      }
    }

    return content;
  },

  search(filter) {
    const data = {
      q: filter || "",
      limit: this.maxTagSearchResults,
      categoryId: this.selectKit.options.categoryId
    };

    if (this.value) {
      data.selected_tags = this.value.slice(0, 100);
    }

    if (!this.selectKit.options.everyTag) data.filterForInput = true;

    return this.searchTags("/tags/filter/search", data, this._transformJson);
  },

  _transformJson(context, json) {
    let results = json.results;

    context.setProperties({
      termMatchesForbidden: json.forbidden ? true : false,
      termMatchErrorMessage: json.forbidden_message
    });

    if (context.get("siteSettings.tags_sort_alphabetically")) {
      results = results.sort((a, b) => a.text.localeCompare(b.text));
    }

    results = results
      .filter(r => !makeArray(context.tags).includes(r.id))
      .map(result => {
        return { id: result.text, name: result.text, count: result.count };
      });

    return results;
  },

  select(value) {
    this._reset();

    if (!this.validateSelect(value)) {
      return;
    }

    const tags = [...new Set(makeArray(this.value).concat(value))];
    this.selectKit.change(tags, tags);
  },

  deselect(value) {
    this._reset();

    const tags = [...new Set(makeArray(this.value).removeObject(value))];
    this.selectKit.change(tags, tags);
  },

  _reset() {
    this.clearErrors();
    this.set("highlightedTag", null);
  },

  _onKeydown(event) {
    const value = makeArray(this.value);

    if (event.keyCode === 8) {
      this._onBackspace(this.value, this.highlightedTag);
    } else if (event.keyCode === 37) {
      if (this.highlightedTag) {
        const index = value.indexOf(this.highlightedTag);
        const highlightedTag = value[index - 1]
          ? value[index - 1]
          : value.lastObject;
        this.set("highlightedTag", highlightedTag);
      } else {
        this.set("highlightedTag", value.lastObject);
      }
    } else if (event.keyCode === 39) {
      if (this.highlightedTag) {
        const index = value.indexOf(this.highlightedTag);
        const highlightedTag = value[index + 1]
          ? value[index + 1]
          : value.firstObject;
        this.set("highlightedTag", highlightedTag);
      } else {
        this.set("highlightedTag", value.firstObject);
      }
    } else {
      this.set("highlightedTag", null);
    }

    return true;
  },

  _onBackspace(value, highlightedTag) {
    if (value && value.length) {
      if (!highlightedTag) {
        this.set("highlightedTag", value.lastObject);
      } else {
        this.deselect(highlightedTag);
      }
    }
  }
});
