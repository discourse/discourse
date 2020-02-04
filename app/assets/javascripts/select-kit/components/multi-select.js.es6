import deprecated from "discourse-common/lib/deprecated";
import SelectKitComponent from "select-kit/components/select-kit";
import { computed } from "@ember/object";
const { makeArray } = Ember;

export default SelectKitComponent.extend({
  pluginApiIdentifiers: ["multi-select"],
  layoutName: "select-kit/templates/components/multi-select",
  classNames: ["multi-select"],
  multiSelect: true,

  selectKitOptions: {
    none: "select_kit.default_header_text",
    clearable: true,
    filterable: true,
    filterIcon: null,
    clearOnClick: true,
    closeOnChange: false,
    autoInsertNoneItem: false,
    headerComponent: "multi-select/multi-select-header",
    filterComponent: "multi-select/multi-select-filter"
  },

  search(filter) {
    return this._super(filter).filter(
      content => !makeArray(this.selectedContent).includes(content)
    );
  },

  deselect(item) {
    this.clearErrors();

    const newContent = this.selectedContent.filter(
      content => this.getValue(item) !== this.getValue(content)
    );

    this.selectKit.change(
      this.valueProperty ? newContent.mapBy(this.valueProperty) : newContent,
      newContent
    );
  },

  select(value, item) {
    if (!value || !value.length) {
      if (!this.validateSelect(this.selectKit.highlighted)) {
        return;
      }

      this.selectKit.change(
        makeArray(this.value).concat(
          makeArray(this.getValue(this.selectKit.highlighted))
        ),
        makeArray(this.selectedContent).concat(
          makeArray(this.selectKit.highlighted)
        )
      );
    } else {
      const existingItem = this.findValue(
        this.mainCollection,
        this.selectKit.valueProperty ? item : value
      );
      if (existingItem) {
        if (!this.validateSelect(item)) {
          return;
        }
      }

      const newValues = makeArray(this.value).concat(makeArray(value));
      const newContent = makeArray(this.selectedContent).concat(
        makeArray(item)
      );

      this.selectKit.change(
        newValues,
        newContent.length
          ? newContent
          : makeArray(this.defaultItem(value, value))
      );
    }
  },

  selectedContent: computed("value.[]", "content.[]", function() {
    const value = Ember.makeArray(this.value);
    if (value.length) {
      let content = [];

      value.forEach(v => {
        if (this.selectKit.valueProperty) {
          const c = makeArray(this.content).findBy(
            this.selectKit.valueProperty,
            v
          );
          if (c) {
            content.push(c);
          }
        } else {
          if (makeArray(this.content).includes(v)) {
            content.push(v);
          }
        }
      });

      return this.selectKit.modifySelection(content || []);
    } else {
      return this.selectKit.noneItem;
    }
  }),

  _onKeydown(event) {
    if (event.keyCode === 8) {
      event.stopPropagation();

      const input = this.getFilterInput();
      if (input && !input.value.length >= 1) {
        const selected = this.element.querySelectorAll(
          ".select-kit-header .choice.select-kit-selected-name"
        );

        if (selected.length) {
          const lastSelected = selected[selected.length - 1];
          if (lastSelected) {
            if (lastSelected.classList.contains("is-highlighted")) {
              this.deselect(this.selectedContent.lastObject);
            } else {
              lastSelected.classList.add("is-highlighted");
            }
          }
        }
      }
    } else {
      const selected = this.element.querySelectorAll(
        ".select-kit-header .choice.select-kit-selected-name"
      );
      selected.forEach(s => s.classList.remove("is-highlighted"));
    }

    return true;
  },

  handleDeprecations() {
    this._super(...arguments);

    this._deprecateValues();
  },

  _deprecateValues() {
    if (this.values && !this.value) {
      deprecated(
        "The `values` property is deprecated for multi-select. Use `value` instead",
        {
          since: "v2.4.0"
        }
      );

      this.set("value", this.values);
    }
  }
});
