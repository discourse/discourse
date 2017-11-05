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

  init() {
    this._super();
    if (isNone(this.get("value"))) { this.set("value", []); }
  },

  @computed("filter")
  templateForCreateRow() {
    return (rowComponent) => {
      return `Create: ${rowComponent.get("content.name")}`;
    };
  },

  @on("didRender")
  _autoHighlight() {
    if (this.get("isExpanded") === false) { return; }
    if (this.get("renderBody") === false) { return; }
    if (!isNone(this.get("highlightedValue"))) { return; }

    if (isEmpty(this.get("filteredContent"))) {
      if (this.get("shouldDisplayCreateRow") === true && !isEmpty(this.get("filter"))) {
        this.send("onHighlight", this.get("filter"));
      } else if (this.get("none") && !isEmpty(this.get("selectedContent"))) {
        this.send("onHighlight", this.NONE_VALUE);
      }
    } else {
      this.send("onHighlight", this.get("filteredContent.firstObject.value"));
    }
  },

  click(event) {
    this.$filterInput().focus();
    return false;
  },

  keyDown(event) {
    const keyCode = event.keyCode || event.which;
    const $filterInput = this.$filterInput();

    // select all choices
    if (event.metaKey === true && keyCode === 65 && isEmpty(this.get("filter"))) {
      this.$(".choices .selected-name").addClass("is-highlighted");
      return;
    }

    // clear selection when multiple
    if (this.$(".selected-name.is-highlighted").length >= 1 && keyCode === 8) {
      const highlightedValues = [];
      $.each(this.$(".selected-name.is-highlighted"), (i, el) => {
        highlightedValues.push($(el).attr("data-value"));
      });

      console.log(highlightedValues)
      this.send("onDeselect", highlightedValues);
      return;
    }

    // try to remove last item from the list
    if (keyCode === 8) {
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
  computedValue(value) {
    return value.map(v => this._castInteger(v));
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

  filterFunction(content) {
    return (selectBox, computedValue) => {
      const filter = selectBox.get("filter").toLowerCase();
      return _.filter(content, c => {
        return !computedValue.includes(get(c, "value")) &&
          get(c, "name").toLowerCase().indexOf(filter) > -1;
      });
    };
  },

  actions: {
    onClearSelection() {
      this.set("highlightedValue", null);
      // this.set("value", []);
      this.send("onDeselect", this.get("selectedContent").map(c => get(c, "value")));
    },

    onHighlight(value) {
      console.log("beforeh", value)
      value = this.originalValueForValue(value);
      console.log("afterh", value)
      this.set("highlightedValue", value);
    },

    onCreateContent(name) {
      this.set("highlightedValue", null);

      if (this.get("content").includes(name)) {
        return;
      }

      this.get("content").pushObject(name);
      this.get("value").pushObject(name);
      this.clearFilter();
    },

    onSelect(value) {
      this._super();
      console.log("before", value)
      value = this.originalValueForValue(value);
      console.log("after", value)


      this.get("value").pushObject(value);
    },

    onDeselect(values) {
      values = Ember.makeArray(values).map(v => this.originalValueForValue(v));

      console.log("-------values", values)
      const contentsToRemove = [];
      values.forEach(v => {
        if (!this.get("_initialValues").includes(v)) {
          contentsToRemove.push(this.contentForValue(v));
        }
      });

      this.get("value").removeObjects(values);
      this.get("content").removeObjects(contentsToRemove);
      this.set("highlightedValue", null);
    }
  }
});
