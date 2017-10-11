import SelectBoxKitComponent from "select-box-kit/components/select-box-kit";
import computed from "ember-addons/ember-computed-decorators";

export default SelectBoxKitComponent.extend({
  classNames: "multi-combobox",
  headerComponent: "multi-combo-box/multi-combo-box-header",
  filterComponent: null,
  headerText: "select_values",
  value: [],

  keyDown(event) {
    const keyCode = event.keyCode || event.which;
    const $filterQuery = this.$(".filter-query");

    if (keyCode === 8) {
      let $lastSelectedValue = $(this.$(".choices .selected-value").last());

      if ($lastSelectedValue.is(":focus") || $(document.activeElement).is($lastSelectedValue)) {
        this.send("onDeselect", $lastSelectedValue.attr("data-value"));
        $filterQuery.focus();
        return;
      }

      if ($filterQuery.val() === "") {
        if ($filterQuery.is(":focus")) {
          if ($lastSelectedValue.length > 0) {
            $lastSelectedValue.focus();
          }
        } else {
          if ($lastSelectedValue.length > 0) {
            $lastSelectedValue.focus();
          } else {
            $filterQuery.focus();
          }
        }
      }
    } else {
      $filterQuery.focus();
      this._super(event);
    }
  },

  @computed("none")
  computedNone(none) {
    if (!Ember.isNone(none)) {
      this.set("none", { name: I18n.t(none), value: "none" });
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
        return !computedValue.includes(Ember.get(c, "value")) &&
          Ember.get(c, "name").toLowerCase().indexOf(filter) > -1;
      });
    };
  },

  actions: {
    onClearSelection() {
      this.defaultOnSelect();
      this.set("value", []);
    },

    onSelect(value) {
      this.set("filter", "");
      this.set("highlightedValue", null);
      this.get("value").pushObject(value);
    },

    onDeselect(value) {
      this.get("value").removeObject(value);
    }
  }
});
