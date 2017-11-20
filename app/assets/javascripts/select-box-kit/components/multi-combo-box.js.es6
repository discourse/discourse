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
  allowInitialValueMutation: false,
  autoSelectFirst: false,
  autoFilterable: true,
  selectedNameComponent: "multi-combo-box/selected-name",

  init() {
    this._super();

    this.set("computedValues", []);
    if (isNone(this.get("values"))) { this.set("values", []); }

    this.set("headerComponentOptions", Ember.Object.create({
      selectedNameComponent: this.get("selectedNameComponent")
    }));
  },

  @on("didReceiveAttrs")
  _compute() {
    Ember.run.scheduleOnce("afterRender", () => {
      this.willComputeAttributes();
      let content = this._beforeWillComputeContent(this.get("content"));
      content = this.willComputeContent(content);
      let values = this._beforeWillComputeValues(this.get("values"));
      content = this.computeContent(content);
      content = this._beforeDidComputeContent(content);
      values = this.willComputeValues(values);
      values = this.computeValues(values);
      values = this._beforeDidComputeValues(values);
      this.didComputeContent(content);
      this.didComputeValues(values);
      this.set("headerComputedContent", this.computeHeaderContent());
      this.didComputeAttributes();
    });
  },

  @computed("filter", "shouldDisplayCreateRow")
  createRowComputedContent(filter, shouldDisplayCreateRow) {
    if (shouldDisplayCreateRow === true) {
      let content = this.createContentFromInput(filter);
      return this.computeContentItem(content);
    }
  },

  _beforeWillComputeValues(values) {
    return values.map(v => this._castInteger(v === "" ? null : v));
  },
  willComputeValues(values) { return values; },
  computeValues(values) { return values; },
  _beforeDidComputeValues(values) {
    this.setProperties({ computedValues: values });
    return values;
  },
  didComputeValues(values) { return values; },

  mutateAttributes() {
    Ember.run.next(() => {
      this.mutateContent(this.get("computedContent"));
      this.mutateValues(this.get("computedValues"));
      this.set("headerComputedContent", this.computeHeaderContent());
    });
  },
  mutateValues(computedValues) { this.set("values", computedValues); },

  filterComputedContent(computedContent, computedValues, filter) {
    computedContent = computedContent.filter(c => {
      return !computedValues.includes(get(c, "value"));
    });

    if (isEmpty(filter)) { return computedContent; }

    const lowerFilter = filter.toLowerCase();
    return computedContent.filter(c => {
      return get(c, "name").toLowerCase().indexOf(lowerFilter) > -1;
    });
  },

  @computed("computedContent.[]", "computedValues.[]", "filter")
  filteredComputedContent(computedContent, computedValues, filter) {
    return this.filterComputedContent(computedContent, computedValues, filter);
  },

  baseHeaderComputedContent() {
    return {
      selectedComputedContents: this.get("selectedComputedContents")
    };
  },

  @computed("filter")
  templateForCreateRow() {
    return (rowComponent) => {
      return I18n.t("select_box.create", { content: rowComponent.get("computedContent.name")});
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
    if (isEmpty(this.get("filter")) && this.$(".selected-name.is-highlighted").length >= 1 && keyCode === this.keys.BACKSPACE) {
      const highlightedComputedContents = [];
      $.each(this.$(".selected-name.is-highlighted"), (i, el) => {
        const computedContent = this._findComputedContentByGuid($(el).attr("data-guid"));
        if (!Ember.isNone(computedContent)) { highlightedComputedContents.push(computedContent); }
      });
      this.send("onDeselect", highlightedComputedContents);
      return;
    }

    // try to remove last item from the list
    if (isEmpty(this.get("filter")) && keyCode === this.keys.BACKSPACE) {
      let $lastSelectedValue = $(this.$(".choices .selected-name:not(.is-locked)").last());

      if ($lastSelectedValue.length === 0) { return; }

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

  @computed("computedValues.[]", "computedContent.[]")
  selectedComputedContents(computedValues, computedContent) {
    const contents = [];
    computedValues.forEach(cv => {
      const content = computedContent.findBy("value", cv);
      if (!isNone(content)) { contents.push(content); }
    });
    return contents;
  },

  createContentFunction(input) {
    const formatedContent = this.formatContentItem(input);
    this.get("computedContent").pushObject(formatedContent);
    this.get("computedValues").pushObject(formatedContent.value);
    this.setValuesFunction();
    this.setContentFunction();
  },

  highlightValueFunction(value) {
    this.set("highlightedValue", value);
  },

  setValuesFunction() {
    this.set("value", this.get("computedValues"));
  },

  setContentFunction() {
    this.set("content", this.get("computedContent").map(c => c.originalContent));
  },

  autoHighlight() {
    Ember.run.schedule("afterRender", () => {
      if (this.get("isExpanded") === false) { return; }
      if (this.get("renderedBodyOnce") === false) { return; }
      if (!isNone(this.get("highlightedValue"))) { return; }

      if (isEmpty(this.get("filteredComputedContent"))) {
        if (!isEmpty(this.get("filter"))) {
          this.send("onHighlight", this.get("createRowComputedContent"));
        } else if (this.get("none") && !isEmpty(this.get("selectedContent"))) {
          this.send("onHighlight", this.get("noneRowComputedContent"));
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
    this.setProperties({ computedValues: values });
    return values;
  },
  didLoadValues() {},

  actions: {
    onClear() {
      this.set("computedValues", []);
      this.mutateAttributes();
    },

    onCreate(input) {
      let content = this.createContentFromInput(input);
      if (Ember.isNone(content)) return;

      const computedContent = this.computeContentItem(content);
      if (this.validateComputedContent(computedContent) &&
          !this.get("computedValues").includes(computedContent.value)) {
        this.get("computedContent").pushObject(computedContent);
        this.get("computedValues").pushObject(computedContent.value);
        this.set("validCreateContent", true);
        this.clearFilter();
        this.autoHighlight();
        this.focus();
        this.mutateAttributes();
      } else {
        this.set("validCreateContent", false);
      }
    },

    onSelect(rowComputedContentItem) {
      this.willSelect(rowComputedContentItem);
      this.get("computedValues").pushObject(rowComputedContentItem.value);
      this.mutateAttributes();
      Ember.run.schedule("afterRender", () => this.didSelect(rowComputedContentItem));
    },

    onDeselect(rowComputedContentItems) {
      const generatedComputedContents = this._filterRemovableComputedContents(rowComputedContentItems);
      this.willDeselect(rowComputedContentItems);
      this.get("computedValues").removeObjects(rowComputedContentItems.map(r => r.value));
      this.get("computedContent").removeObjects(generatedComputedContents);
      this.mutateAttributes();
      Ember.run.schedule("afterRender", () => this.didDeselect(rowComputedContentItems));
    }
  }
});
