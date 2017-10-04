import SelectBoxKitComponent from "select-box-kit/components/select-box-kit";
import { on } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";

export default SelectBoxKitComponent.extend({
  classNames: "multi-combobox",

  headerComponent: "multi-combo-box/multi-combo-box-header",

  headerText: "select_values",

  value: Ember.A(),

  @on("init")
  _localizeNone() {
    if (!Ember.isNone(this.get("none"))) {
      this.set("none", {name: I18n.t(this.get("none")), value: "none"});
    }
  },

  @computed("value.[]", "content.[]")
  selectedContents(value, content) {
    const contents = Ember.A();

    value.forEach((v) => {
      const c = content.findBy("value", v);
      contents.push(c);
    });

    return contents;
  },

  @computed("content.[]", "selectedContents.[]", "filter")
  filteredContent(content, selectedContents) {
    const filteredContent = this._super();
    const selectedContentsIds = selectedContents.map((c) => Ember.get(c, "value") );

    return filteredContent.filter((c) => {
      return !selectedContentsIds.includes(Ember.get(c, "value"));
    });
  },

  actions: {
    onSelectNone() {
      this.defaultOnSelect();
      this.set("value", Ember.A());
    },

    onSelect(value) {
      this.defaultOnSelect();
      this.get("value").pushObject(value);
    },

    onDeselect(value) {
      this.get("value").removeObject(value);
    }
  }
});
