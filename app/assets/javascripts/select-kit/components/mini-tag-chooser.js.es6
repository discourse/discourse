import ComboBox from "select-kit/components/combo-box";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from 'discourse/lib/ajax-error';
import { default as computed } from "ember-addons/ember-computed-decorators";
import renderTag from "discourse/lib/render-tag";
const { get, isEmpty, isPresent, run } = Ember;

export default ComboBox.extend({
  allowContentReplacement: true,
  pluginApiIdentifiers: ["mini-tag-chooser"],
  classNames: ["mini-tag-chooser"],
  classNameBindings: ["noTags"],
  verticalOffset: 3,
  filterable: true,
  noTags: Ember.computed.empty("computedTags"),
  allowAny: true,

  init() {
    this._super();

    this.set("termMatchesForbidden", false);

    this.set("templateForRow", (rowComponent) => {
      const tag = rowComponent.get("computedContent");
      return renderTag(get(tag, "value"), {
        count: get(tag, "originalContent.count"),
        noHref: true
      });
    });
  },

  @computed("tags")
  computedTags(tags) {
    return Ember.makeArray(tags);
  },

  validateCreate(term) {
    const filterRegexp = new RegExp(this.site.tags_filter_regexp, "g");
    term = term.replace(filterRegexp, "").trim().toLowerCase();

    if (!term.length || this.get("termMatchesForbidden")) {
      return false;
    }

    if (this.get("siteSettings.max_tag_length") < term.length) {
      return false;
    }

    return true;
  },

  validateSelect() {
    return this.get("computedTags").length < this.get("siteSettings.max_tags_per_topic") &&
           this.site.get("can_create_tag");
  },

  didRender() {
    this._super();

    this.$().on("click.mini-tag-chooser", ".selected-tag", (event) => {
      event.stopImmediatePropagation();
      this.send("removeTag", $(event.target).attr("data-value"));
    });
  },

  willDestroyElement() {
    this._super();

    $(".select-kit-body").off("click.mini-tag-chooser");

    const searchDebounce = this.get("searchDebounce");
    if (isPresent(searchDebounce)) { run.cancel(searchDebounce); }
  },

  didPressEscape(event) {
    const $lastSelectedTag = $(".selected-tag.selected:last");

    if ($lastSelectedTag && this.get("isExpanded")) {
      $lastSelectedTag.removeClass("selected");
      this._destroyEvent(event);
    } else {
      this._super(event);
    }
  },

  backspaceFromFilter(event) {
    this.didPressBackspace(event);
  },

  didPressBackspace() {
    if (!this.get("isExpanded")) {
      this.expand();
      return;
    }

    const $lastSelectedTag = $(".selected-tag:last");

    if (!isEmpty(this.get("filter"))) {
      $lastSelectedTag.removeClass("is-highlighted");
      return;
    }

    if (!$lastSelectedTag.length) return;

    if (!$lastSelectedTag.hasClass("is-highlighted")) {
      $lastSelectedTag.addClass("is-highlighted");
    } else {
      this.send("removeTag", $lastSelectedTag.attr("data-value"));
    }
  },

  @computed("tags.[]", "filter")
  collectionHeader(tags, filter) {
    if (!Ember.isEmpty(tags)) {
      let output = "";

      if (tags.length >= 20) {
        tags = tags.filter(t => t.indexOf(filter) >= 0);
      }

      tags.map((tag) => {
        output += `
          <button class="selected-tag" data-value="${tag}">
            ${tag}
          </button>
        `;
      });

      return `<div class="selected-tags">${output}</div>`;
    }
  },

  computeHeaderContent() {
    let content = this.baseHeaderComputedContent();

    if (isEmpty(this.get("computedTags"))) {
      content.label = I18n.t("tagging.choose_for_topic");
    } else {
      content.label = this.get("computedTags").join(",");
    }

    return content;
  },

  actions: {
    removeTag(tag) {
      let tags = this.get("computedTags");
      delete tags[tags.indexOf(tag)];
      this.set("tags", tags.filter(t => t));
      this.set("content", []);
      this.set("searchDebounce", run.debounce(this, this._searchTags, 200));
    },

    onExpand() {
      this.set("searchDebounce", run.debounce(this, this._searchTags, 200));
    },

    onFilter(filter) {
      filter = isEmpty(filter) ? null : filter;
      this.set("searchDebounce", run.debounce(this, this._searchTags, filter, 200));
    },

    onSelect(tag) {
      if (isEmpty(this.get("computedTags"))) {
        this.set("tags", Ember.makeArray(tag));
      } else {
        this.set("tags", this.get("computedTags").concat(tag));
      }

      this.set("content", []);
      this.set("searchDebounce", run.debounce(this, this._searchTags, 200));
    }
  },

  muateAttributes() {
    this.set("value", null);
  },

  _searchTags(query) {
    this.startLoading();

    const selectedTags = Ember.makeArray(this.get("computedTags")).filter(t => t);

    const self = this;

    const sortTags = this.siteSettings.tags_sort_alphabetically;

    const data = {
      q: query,
      limit: this.siteSettings.max_tag_search_results,
      categoryId: this.get("categoryId")
    };

    if (selectedTags) {
      data.selected_tags = selectedTags.slice(0, 100);
    }

    ajax(Discourse.getURL("/tags/filter/search"), {
        quietMillis: 200,
        cache: true,
        dataType: "json",
        data,
      }).then(json => {
        let results = json.results;

        self.set("termMatchesForbidden", json.forbidden ? true : false);

        if (sortTags) {
          results = results.sort((a, b) => a.id > b.id);
        }

        const content = results.map((result) => {
          return {
            id: result.text,
            name: result.text,
            count: result.count
          };
        }).filter(c => !selectedTags.includes(c.id));

        self.set("content", content);
        self.stopLoading();
        this.autoHighlight();
      }).catch(error => {
        self.stopLoading();
        popupAjaxError(error);
      });
  }
});
