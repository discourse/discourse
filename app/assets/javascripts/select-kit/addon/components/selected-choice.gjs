import Component from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { computed } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { tagName } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import selectKitPropUtils from "select-kit/lib/select-kit-prop-utils";

@tagName("")
@selectKitPropUtils
export default class SelectedChoice extends Component {
  item = null;
  selectKit = null;
  extraClass = null;
  id = null;

  init() {
    super.init(...arguments);

    this.set("id", guidFor(this));
  }

  @computed("item")
  get itemValue() {
    return this.getValue(this.item);
  }

  @computed("item")
  get itemName() {
    return this.getName(this.item);
  }

  @computed("item")
  get mandatoryValuesArray() {
    return this.get("mandatoryValues")?.split("|") || [];
  }

  @computed("item")
  get readOnly() {
    if (typeof this.item === "string") {
      return this.mandatoryValuesArray.includes(this.item);
    }
    return this.mandatoryValuesArray.includes(this.item.id);
  }

  <template>
    {{#if this.readOnly}}
      <button
        class="btn btn-default disabled"
        title={{i18n "admin.site_settings.mandatory_group"}}
      >{{this.itemName}}</button>
    {{else}}
      <button
        {{on "click" (fn this.selectKit.deselect this.item)}}
        aria-label={{i18n "select_kit.delete_item" name=this.itemName}}
        data-value={{this.itemValue}}
        data-name={{this.itemName}}
        type="button"
        id="{{this.id}}-choice"
        class="btn btn-default selected-choice {{this.extraClass}}"
      >
        {{icon "xmark"}}
        {{#if (has-block)}}
          {{yield}}
        {{else}}
          <span class="d-button-label">
            {{this.itemName}}
          </span>
        {{/if}}
      </button>
    {{/if}}
  </template>
}
