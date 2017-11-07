import SelectBoxKitComponent from "select-box-kit/components/select-box-kit";
import computed from "ember-addons/ember-computed-decorators";
import { on } from "ember-addons/ember-computed-decorators";
const { get, isNone, isEmpty } = Ember;

export default SelectBoxKitComponent.extend({
  classNames: "multi-combo-box",
  headerComponent: "multi-combo-box/multi-combo-box-header",
  filterComponent: null,
  headerText: "select_box.default_header_text",
  allowAny: true,
  allowValueMutation: false,
  autoSelectFirst: false,
  autoFilterable: true,
  selectedNameComponent: "multi-combo-box/selected-name",

  init() {
    this._super();

    if (isNone(this.get("value"))) { this.set("value", []); }

    this.set("headerComponentOptions", Ember.Object.create({
      selectedNameComponent: this.get("selectedNameComponent")
    }));
  },

  @computed("filter")
  templateForCreateRow() {
    return (rowComponent) => {
      return I18n.t("select_box.create", { content: rowComponent.get("content.name")});
    };
  },

  @on("didRender")
  autoHighlightFunction() {
    if (this.get("isExpanded") === false) { return; }
    if (this.get("renderedBodyOnce") === false) { return; }
    if (!isNone(this.get("highlightedValue"))) { return; }

    if (isEmpty(this.get("filteredContent"))) {
      if (this.get("shouldDisplayCreateRow") === true && !isEmpty(this.get("filter"))) {
        this.send("onHighlight", this.get("filter"));
      } else if (this.get("none") && !isEmpty(this.get("selectedContent"))) {
        this.send("onHighlight", this.noneValue);
      }
    } else {
      this.send("onHighlight", this.get("filteredContent.firstObject.value"));
    }
  },

  keyDown(event) {
    const keyCode = event.keyCode || event.which;
    const $filterInput = this.$filterInput();

    if (this.get("isFocused") === true && this.get("isExpanded") === false && keyCode === 8) {
      this.expand();
      return;
    }

    // select all choices
    if (event.metaKey === true && keyCode === 65 && isEmpty(this.get("filter"))) {
      this.$(".choices .selected-name").addClass("is-highlighted");
      return;
    }

    // clear selection when multiple
    if (Ember.isEmpty(this.get("filter")) && this.$(".selected-name.is-highlighted").length >= 1 && keyCode === 8) {
      const highlightedValues = [];
      $.each(this.$(".selected-name.is-highlighted"), (i, el) => {
        highlightedValues.push($(el).attr("data-value"));
      });

      this.send("onDeselect", highlightedValues);
      return;
    }

    // try to remove last item from the list
    if (Ember.isEmpty(this.get("filter")) && keyCode === 8) {
      let $lastSelectedValue = $(this.$(".choices .selected-name").last());

      if ($lastSelectedValue.length === 0) { return; }

      if ($lastSelectedValue.hasClass("is-highlighted") || $(document.activeElement).is($lastSelectedValue)) {
        this.send("onDeselect", this.get("selectedContent.lastObject.value"));
        $filterInput.focus();
        return;
      }

      if ($filterInput.val() === "") {
        if ($filterInput.is(":focus")) {
          if ($lastSelectedValue.length > 0) { $lastSelectedValue.click(); }
        } else {
          if ($lastSelectedValue.length > 0) {
            $lastSelectedValue.click();
          } else {
            $filterInput.focus();
          }
        }
      }
    }
  },

  @computed("value.[]")
  computedValue(value) { return value.map(v => this._castInteger(v)); },

  @computed("computedValue.[]", "computedContent.[]")
  selectedContent(computedValue, computedContent) {
    const contents = [];
    computedValue.forEach(cv => {
      const content = computedContent.findBy("value", cv);
      if (!isNone(content)) { contents.push(content); }
    });
    return contents;
  },

  filterFunction(content, filter) {
    return (selectBox) => {
      const lowerFilter = filter.toLowerCase();
      return _.filter(content, c => {
        return !selectBox.get("computedValue").includes(get(c, "value")) &&
          get(c, "name").toLowerCase().indexOf(lowerFilter) > -1;
      });
    };
  },

  baseOnHighlight(value) {
    value = this.originalValueForValue(value);
    this.set("highlightedValue", value);
    return value;
  },

  baseOnSelect(value) {
    this.clearFilter();
    this.set("highlightedValue", null);
    this.expand();
    return this.originalValueForValue(value);
  },

  baseOnCreateContent(input) {
    this.set("highlightedValue", null);
    this.clearFilter();
    return this.createFunction(input)(this);;
  },

  baseOnDeselect(values) {
    values = Ember.makeArray(values)
                  .map(v => this.originalValueForValue(v))
                  .filter(v => {
                    return get(this.computedContentForValue(v), "locked") !== true;
                  });

    const contentsToRemove = [];
    values.forEach(v => {
      if (!this.get("_initialValues").includes(v)) {
        const content = this.contentForValue(v);
        if (!isNone(content)) { contentsToRemove.push(content); }
      }
    });
    this.set("highlightedValue", null);
    return { values, contentsToRemove };
  },

  actions: {
    onClearSelection() {
      this.set("highlightedValue", null);
      this.send("onDeselect", this.get("selectedContent").map(c => get(c, "value")));
    },

    onHighlight(value) {
      this.baseOnHighlight(value);
    },

    onCreateContent(input) {
      const content = this.baseOnCreateContent(input);

      if (!this.get("content").includes(content)) {
        this.get("content").pushObject(content);
        this.get("value").pushObject(content);
      }
    },

    onSelect(value) {
      value = this.baseOnSelect(value);
      this.get("value").pushObject(value);
    },

    onDeselect(values) {
      const deselectState = this.baseOnDeselect(values);
      this.get("value").removeObjects(deselectState.values);
      this.get("content").removeObjects(deselectState.contentsToRemove);
    }
  }
});
