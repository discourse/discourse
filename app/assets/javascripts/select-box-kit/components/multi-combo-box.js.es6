// Experimental
import SelectBoxKitComponent from "select-box-kit/components/select-box-kit";
import computed from "ember-addons/ember-computed-decorators";
const { get, isNone } = Ember;

export default SelectBoxKitComponent.extend({
  classNames: "multi-combobox",
  headerComponent: "multi-combo-box/multi-combo-box-header",
  filterComponent: null,
  headerText: "select_box.default_header_text",
  value: [],
  allowAny: true,

  @computed("filter")
  templateForCreateRow() {
    return (rowComponent) => {
      return `Create: ${rowComponent.get("content.name")}`;
    };
  },

  keyDown(event) {
    const keyCode = event.keyCode || event.which;
    const $filterInput = this.$filterInput();

    if (keyCode === 8) {
      let $lastSelectedValue = $(this.$(".choices .selected-name").last());

      if ($lastSelectedValue.is(":focus") || $(document.activeElement).is($lastSelectedValue)) {
        this.send("onDeselect", $lastSelectedValue.data("value"));
        $filterInput.focus();
        return;
      }

      if ($filterInput.val() === "") {
        if ($filterInput.is(":focus")) {
          if ($lastSelectedValue.length > 0) {
            $lastSelectedValue.focus();
          }
        } else {
          if ($lastSelectedValue.length > 0) {
            $lastSelectedValue.focus();
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

  @computed("none")
  computedNone(none) {
    if (!isNone(none)) {
      this.set("none", { name: I18n.t(none), value: "" });
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
      contents.push(computedContent.findBy("value", cv));
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
      this.send("onSelect", []);
    },

    onSelect(value) {
      this.setProperties({ filter: "", highlightedValue: null });
      this.get("value").pushObject(value);
    },

    onDeselect(value) {
      this.defaultOnDeselect(value);
      this.get("value").removeObject(value);
    }
  }
});
