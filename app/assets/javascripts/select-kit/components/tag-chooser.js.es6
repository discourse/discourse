import MultiSelectComponent from "select-kit/components/multi-select";
import Tags from "select-kit/mixins/tags";
import renderTag from "discourse/lib/render-tag";
import computed from "ember-addons/ember-computed-decorators";
const { get, run, makeArray } = Ember;

export default MultiSelectComponent.extend(Tags, {
  pluginApiIdentifiers: ["tag-chooser"],
  classNames: "tag-chooser",
  isAsync: true,
  filterable: true,
  filterPlaceholder: "tagging.choose_for_topic",
  limit: null,
  blacklist: null,
  attributeBindings: ["categoryId"],
  allowAny: Ember.computed.alias("allowCreate"),

  init() {
    this._super();

    if (this.get("allowCreate") !== false) {
      this.set("allowCreate", this.site.get("can_create_tag"));
    }

    if (!this.get("blacklist")) {
      this.set("blacklist", []);
    }

    this.set("termMatchesForbidden", false);

    this.set("templateForRow", rowComponent => {
      const tag = rowComponent.get("computedContent");
      return renderTag(get(tag, "value"), {
        count: get(tag, "originalContent.count"),
        noHref: true
      });
    });

    if (!this.get("unlimitedTagCount")) {
      this.set(
        "maximum",
        parseInt(
          this.get("limit") ||
            this.get("maximum") ||
            this.get("siteSettings.max_tags_per_topic")
        )
      );
    }
  },

  mutateValues(values) {
    this.set("tags", values.filter(v => v));
  },

  @computed("tags")
  values(tags) {
    return makeArray(tags);
  },

  @computed("tags")
  content(tags) {
    return makeArray(tags);
  },

  actions: {
    onFilter(filter) {
      this.expand();
      this.set(
        "searchDebounce",
        run.debounce(this, this._prepareSearch, filter, 200)
      );
    },

    onExpand() {
      this.set(
        "searchDebounce",
        run.debounce(this, this._prepareSearch, this.get("filter"), 200)
      );
    },

    onDeselect() {
      this.set(
        "searchDebounce",
        run.debounce(this, this._prepareSearch, this.get("filter"), 200)
      );
    },

    onSelect() {
      this.set(
        "searchDebounce",
        run.debounce(this, this._prepareSearch, this.get("filter"), 50)
      );
    }
  },

  _prepareSearch(query) {
    const selectedTags = makeArray(this.get("values")).filter(t => t);

    const data = {
      q: query,
      limit: this.get("siteSettings.max_tag_search_results"),
      categoryId: this.get("categoryId")
    };

    if (selectedTags.length || this.get("blacklist").length) {
      data.selected_tags = _.uniq(
        selectedTags.concat(this.get("blacklist"))
      ).slice(0, 100);
    }

    if (!this.get("everyTag")) data.filterForInput = true;

    this.searchTags("/tags/filter/search", data, this._transformJson);
  },

  _transformJson(context, json) {
    let results = json.results;

    context.set("termMatchesForbidden", json.forbidden ? true : false);

    if (context.get("blacklist")) {
      results = results.filter(result => {
        return !context.get("blacklist").includes(result.id);
      });
    }

    if (context.get("siteSettings.tags_sort_alphabetically")) {
      results = results.sort((a, b) => a.id > b.id);
    }

    results = results.map(result => {
      return { id: result.text, name: result.text, count: result.count };
    });

    // if forbidden we probably have an existing tag which is not in the list of
    // returned tags, so we manually add it at the top
    if (json.forbidden) {
      results.unshift({ id: json.forbidden, name: json.forbidden, count: 0 });
    }

    return results;
  }
});
