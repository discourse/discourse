import SelectBoxKitComponent from "select-box-kit/components/select-box-kit";
import computed from "ember-addons/ember-computed-decorators";
const { get, isNone, isEmpty } = Ember;

export default SelectBoxKitComponent.extend({
  classNames: "multi-combo-box",
  headerComponent: "multi-combo-box/multi-combo-box-header",
  filterComponent: null,
  headerText: "select_box.default_header_text",
  allowAny: true,
  allowInitialValueMutation: false,
  autoSelectFirst: false,
  autoFilterable: true,
  selectedNameComponent: "multi-combo-box/selected-name",

  init() {
    this._super();

    this.set("computedValue", []);
    if (isNone(this.get("value"))) { this.set("value", []); }

    this.set("headerComponentOptions", Ember.Object.create({
      selectedNameComponent: this.get("selectedNameComponent")
    }));
  },

  transformInputs() {
    this.send("onReceiveContent", Ember.makeArray(this.get("content")));
    this.send("onReceiveValues", Ember.makeArray(this.get("value")));
  },

  @computed("filter")
  templateForCreateRow() {
    return (rowComponent) => {
      return I18n.t("select_box.create", { content: rowComponent.get("content.name")});
    };
  },

  keyDown(event) {
    const keyCode = event.keyCode || event.which;
    const $filterInput = this.$filterInput();

    if (this.get("isFocused") === true && this.get("isExpanded") === false && keyCode === this.keys.BACKSPACE) {
      this.expand();
      return;
    }

    // select all choices
    if (event.metaKey === true && keyCode === 65 && isEmpty(this.get("filter"))) {
      this.$(".choices .selected-name:not(.is-locked)").addClass("is-highlighted");
      return;
    }

    // clear selection when multiple
    if (Ember.isEmpty(this.get("filter")) && this.$(".selected-name.is-highlighted").length >= 1 && keyCode === this.keys.BACKSPACE) {
      const highlightedValues = [];
      $.each(this.$(".selected-name.is-highlighted"), (i, el) => {
        highlightedValues.push($(el).attr("data-value"));
      });

      this.send("onDeselect", highlightedValues);
      return;
    }

    // try to remove last item from the list
    if (Ember.isEmpty(this.get("filter")) && keyCode === this.keys.BACKSPACE) {
      let $lastSelectedValue = $(this.$(".choices .selected-name:not(.is-locked)").last());

      if ($lastSelectedValue.length === 0) { return; }

      if ($lastSelectedValue.hasClass("is-highlighted") || $(document.activeElement).is($lastSelectedValue)) {
        this.send("onDeselect", this.get("selectedContent.lastObject.value"));
        $filterInput.focus();
        return;
      }

      if ($filterInput.not(":visible") && $lastSelectedValue.length > 0) {
        $lastSelectedValue.click();
        return false;
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

  @computed("computedValue.[]", "computedContent.[]")
  selectedContent(computedValue, computedContent) {
    const contents = [];
    computedValue.forEach(cv => {
      const content = computedContent.findBy("value", cv);
      if (!isNone(content)) { contents.push(content); }
    });
    return contents;
  },

  filteredComputedContentFunction(computedContent, computedValue, filter) {
    computedContent = computedContent.filter(c => {
      return !computedValue.includes(get(c, "value"));
    });

    if (isEmpty(filter)) { return computedContent; }

    const lowerFilter = filter.toLowerCase();
    return computedContent.filter(c => {
      return get(c, "name").toLowerCase().indexOf(lowerFilter) > -1;
    });
  },

  willCreateContent() {
    this.set("highlightedValue", null);
  },

  didCreateContent() {
    this.clearFilter();
    this.autoHighlight();
  },

  createContentFunction(input) {
    const formatedContent = this.formatContentItem(input);
    this.get("computedContent").pushObject(formatedContent);
    this.get("computedValue").pushObject(formatedContent.value);
    this.setValuesFunction();
    this.setContentFunction();
  },

  deselectValuesFunction(values) {
    const contents = this._computeRemovableContentsForValues(values);
    this.get("computedValue").removeObjects(values);
    this.set("computedContent", this.get("computedContent").reject((x) => {
      return values.includes(x.value) && !this.get("_initialValues").includes(x.value)
    }));
    this.setValuesFunction();
    this.setContentFunction();
  },

  highlightValueFunction(value) {
    this.set("highlightedValue", value);
  },

  setValuesFunction() {
    this.set("value", this.get("computedValue"));
  },

  setContentFunction() {
    this.set("content", this.get("computedContent").map(c => c.originalContent));
  },

  willSelectValues() {
    this.expand();
    this.set("highlightedValue", null);
  },
  selectValuesFunction(values) {
    this.set("computedValue", this.get("computedValue").concat(values));
    this.setValuesFunction();
  },
  didSelectValues() {
    this.focus();
    this.clearFilter();
    this.autoHighlight();
  },

  willDeselectValues() {
    this.set("highlightedValue", null);
  },

  didDeselectValues() {
    this.autoHighlight();
  },

  willHighlightValue() {},

  didHighlightValue() {},

  autoHighlight() {
    Ember.run.schedule("afterRender", () => {
      if (this.get("isExpanded") === false) { return; }
      if (this.get("renderedBodyOnce") === false) { return; }
      if (!isNone(this.get("highlightedValue"))) { return; }

      if (isEmpty(this.get("filteredComputedContent"))) {
        if (!isEmpty(this.get("filter"))) {
          this.send("onHighlight", this.get("createRowContent"));
        } else if (this.get("none") && !isEmpty(this.get("selectedContent"))) {
          this.send("onHighlight", this.get("noneRowContent"));
        }
      } else {
        this.send("onHighlight", this.get("filteredComputedContent.firstObject"));
      }
    });
  },

  _beforeWillLoadValues(values) {
    return values.map(v => this._castInteger(v === "" ? null : v));
  },
  willLoadValues(values) { return values; },
  loadValuesFunction(values) { return values; },
  _beforeDidLoadValues(values) {
    this.setProperties({ computedValue: values });
    return values;
  },
  didLoadValues() {},

  actions: {
    onReceiveValues(values) {
      values = this._beforeWillLoadValues(values);
      values = this.willLoadValues(values);
      values = this.loadValuesFunction(values);
      values = this._beforeDidLoadValues(values);
      this.didLoadValues(values);
    },

    onClear() {
      const values = this.get("selectedContent").map(c => get(c, "value"));
      this.send("onDeselect", values);
    },

    onHighlight(value) {
      value = this._originalValueForValue(value);
      this.willHighlightValue(value);
      this.set("highlightedValue", value);
      this.highlightValueFunction(value);
      this.didHighlightValue(value);
    },

    onCreate(input) {
      this.willCreateContent(input);
      this.createContentFunction(input);
      this.didCreateContent(input);
    },

    onSelect(values) {
      values = Ember.makeArray(values).map(v => this._originalValueForValue(v));
      this.willSelectValues(values);
      this.selectValuesFunction(values);
      this.didSelectValues(values);
    },

    onDeselect(values) {
      values = Ember.makeArray(this._computeRemovableValues(values));
      this.willDeselectValues(values);
      this.deselectValuesFunction(values);
      this.didSelectValues(values);
    }
  },

  _computeRemovableContentsForValues(values) {
    const removableContents = [];
    values.forEach(v => {
      if (!this.get("_initialValues").includes(v)) {
        const content = this._computedContentForValue(v);
        if (!isNone(content)) { removableContents.push(content); }
      }
    });
    return removableContents;
  },

  _computeRemovableValues(values) {
    return Ember.makeArray(values)
      .map(v => this._originalValueForValue(v))
      .filter(v => {
        return get(this._computedContentForValue(v), "locked") !== true;
      });
  }
});
