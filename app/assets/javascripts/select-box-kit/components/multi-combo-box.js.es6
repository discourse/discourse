import SelectBoxKitComponent from "select-box-kit/components/select-box-kit";
import computed from "ember-addons/ember-computed-decorators";
import { on } from "ember-addons/ember-computed-decorators";
const { get, isNone, isEmpty } = Ember;

export default SelectBoxKitComponent.extend({
  classNames: "multi-combobox",
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

  @on("willRender")
  _autoHighlight() {
    if (this.get("renderBody") === false) { return; }
    if (!isNone(this.get("highlightedValue"))) { return; }

    if (isEmpty(this.get("filteredContent"))) {
      console.log("---", this.get("shouldDisplayCreateRow"), this.get("filter"))
      if (this.get("shouldDisplayCreateRow") === true) {
        this.send("onHighlight", this.get("filter"));
      }
    } else {
      this.send("onHighlight", this.get("filteredContent.firstObject.value"));
    }
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
    if (this.$(".choices .selected-name.is-highlighted").length >= 1) {
      if (keyCode === 8) {
        $.each(this.$(".choices .selected-name.is-highlighted"), (index, element) => {
          this.send("onDeselect", $(element).attr("data-value"));
        });
        return;
      } else {
        this.$(".choices .selected-name").click();
      }
    }

    // try to remove last item from the list
    if (keyCode === 8) {
      let $lastSelectedValue = $(this.$(".choices .selected-name").last());

      if ($lastSelectedValue.length === 0) {
        this.send("onClearSelection");
        return;
      }

      if ($lastSelectedValue.hasClass("is-highlighted") || $(document.activeElement).is($lastSelectedValue)) {
        this.send("onDeselect", $lastSelectedValue.attr("data-value"));
        $filterInput.focus();
        return;
      }

      if ($filterInput.val() === "") {
        if ($filterInput.is(":focus")) {
          if ($lastSelectedValue.length > 0) {
            $lastSelectedValue.click();
          }
        } else {
          if ($lastSelectedValue.length > 0) {
            $lastSelectedValue.click();
          } else {
            $filterInput.focus();
          }
        }
      }
    } else {
      $filterInput.focus();
      this._super(event);
    }
  },

  @computed("value.[]")
  computedValue() {
    return [ this._super() ].reject(x => isEmpty(x));
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
    onClearSelection() { this.set("value", []); },

    onHighlight(value) { this.set("highlightedValue", value); },

    onSelect(value) {
      // if (isNone(value) || isNone(this.contentForValue(value))) {
      //   this.$filterInput().focus();
      //   return;
      // };
      //

      this.get("value").pushObject(value);
    },

    onDeselect(value) {
      this.defaultOnDeselect(value);
      this.get("value").removeObject(value);
    },

    defaultOnSelect(value) {
      if (isNone(value) || isNone(this.contentForValue(value))) {
        this.$filterInput().focus();
        return;
      };

      // this.setProperties({ filter: "", highlightedValue: null });

      Ember.run.schedule("afterRender", () => {
        this.$filterInput().val("").focus();
      });
    }
  }
});
