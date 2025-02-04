import Component from "@ember/component";
import { computed, get } from "@ember/object";
import { reads } from "@ember/object/computed";
import { guidFor } from "@ember/object/internals";
import { tagName } from "@ember-decorators/component";
import { makeArray } from "discourse/lib/helpers";
import UtilsMixin from "select-kit/mixins/utils";

@tagName("")
export default class SelectedName extends Component.extend(UtilsMixin) {
  name = null;
  value = null;
  headerTitle = null;
  headerLang = null;
  headerLabel = null;
  id = null;

  @reads("headerLang") lang;

  init() {
    super.init(...arguments);

    this.set("id", guidFor(this));
  }

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    // we can't listen on `item.nameProperty` given it's variable
    this.setProperties({
      headerLabel: this.getProperty(this.item, "labelProperty"),
      headerTitle: this.getProperty(this.item, "titleProperty"),
      headerLang: this.getProperty(this.item, "langProperty"),
      name: this.getName(this.item),
      value:
        this.item === this.selectKit.noneItem ? null : this.getValue(this.item),
    });
  }

  @computed("item", "sanitizedTitle")
  get ariaLabel() {
    return this._safeProperty("ariaLabel", this.item) || this.sanitizedTitle;
  }

  // this might need a more advanced solution
  // but atm it's the only case we have to handle
  @computed("title")
  get sanitizedTitle() {
    return String(this.title).replace("&hellip;", "");
  }

  @computed("headerTitle", "item")
  get title() {
    return (
      this.headerTitle ||
      this._safeProperty("title", this.item) ||
      this.name ||
      ""
    );
  }

  @computed("headerLabel", "title", "name")
  get label() {
    return (
      this.headerLabel ||
      this._safeProperty("label", this.item) ||
      this.title ||
      this.name
    );
  }

  @computed("item.{icon,icons}")
  get icons() {
    const icon = makeArray(this._safeProperty("icon", this.item));
    const icons = makeArray(this._safeProperty("icons", this.item));
    return icon.concat(icons).filter(Boolean);
  }

  _safeProperty(name, content) {
    if (!content) {
      return null;
    }

    return get(content, name);
  }
}
