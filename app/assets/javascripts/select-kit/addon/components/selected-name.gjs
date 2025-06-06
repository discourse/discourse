import Component from "@ember/component";
import { fn } from "@ember/helper";
import { computed, get } from "@ember/object";
import { reads } from "@ember/object/computed";
import { guidFor } from "@ember/object/internals";
import { tagName } from "@ember-decorators/component";
import { and } from "truth-helpers";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { makeArray } from "discourse/lib/helpers";
import selectKitPropUtils from "select-kit/lib/select-kit-prop-utils";

@tagName("")
@selectKitPropUtils
export default class SelectedName extends Component {
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
      renderIcon: this.canDisplayIcon,
      value:
        this.item === this.selectKit.noneItem ? null : this.getValue(this.item),
    });
  }

  @computed("selectKit.options.shouldDisplayIcon")
  get canDisplayIcon() {
    return this.selectKit.options.shouldDisplayIcon ?? true;
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
    const _icon = makeArray(this._safeProperty("icon", this.item));
    const icons = makeArray(this._safeProperty("icons", this.item));
    return _icon.concat(icons).filter(Boolean);
  }

  _safeProperty(name, content) {
    if (!content) {
      return null;
    }

    return get(content, name);
  }

  <template>
    {{#if this.selectKit.options.showFullTitle}}
      <div
        lang={{this.lang}}
        title={{this.title}}
        data-value={{this.value}}
        data-name={{this.name}}
        class="select-kit-selected-name selected-name choice"
      >
        {{#if this.selectKit.options.formName}}
          <input
            type="hidden"
            name={{this.selectKit.options.formName}}
            value={{this.value}}
          />
        {{/if}}

        {{#if (and this.renderIcon this.item.icon)}}
          {{icon this.item.icon}}
        {{/if}}

        <span class="name">
          {{this.label}}
        </span>

        {{#if this.shouldDisplayClearableButton}}
          <DButton
            @icon="xmark"
            @action={{fn this.selectKit.deselect this.item}}
            @ariaLabel="clear_input"
            class="btn-clear"
          />
        {{/if}}
      </div>
    {{else}}
      {{#if this.item.icon}}
        <div
          lang={{this.lang}}
          class="select-kit-selected-name selected-name choice"
        >
          {{icon this.item.icon}}
        </div>
      {{/if}}
    {{/if}}
  </template>
}
