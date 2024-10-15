import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import dIcon from "discourse-common/helpers/d-icon";
import I18n from "discourse-i18n";

export default class TableHeaderToggle extends Component {
  get id() {
    return `table-header-toggle-${this.args.field.replace(/\s/g, "")}`;
  }

  get labelKey() {
    if (!this.args.automatic && !this.args.translated) {
      return this.args.field;
    } else {
      return this.args.labelKey;
    }
  }

  get ariaSort() {
    if (this.args.order === this.args.field) {
      return this.args.asc ? "ascending" : "descending";
    } else {
      return "none";
    }
  }

  get chevronIcon() {
    if (this.args.order === this.args.field) {
      return this.args.asc ? "chevron-up" : "chevron-down";
    }
  }

  get pressedState() {
    if (this.args.order === this.args.field) {
      return this.args.asc ? "mixed" : "true";
    } else {
      return "false";
    }
  }

  get ariaLabel() {
    let criteria = "";

    if (this.args.icon === "heart") {
      criteria += `${I18n.t("likes_lowercase", { count: 2 })} `;
    }

    if (this.args.translated) {
      criteria += this.args.field;
    } else {
      const labelKey = this.labelKey || `directory.${this.args.field}`;
      criteria += I18n.t(`${labelKey}_long`, {
        defaultValue: I18n.t(labelKey),
      });
    }

    return I18n.t("directory.sort.label", { criteria });
  }

  get iconName() {
    return this.args.icon || null;
  }

  get label() {
    const labelKey = this.args.labelKey || `directory.${this.args.field}`;
    return this.args.translated
      ? this.args.field
      : I18n.t(`${labelKey}_long`, {
          defaultValue: I18n.t(labelKey),
        });
  }

  @action
  toggleProperties() {
    let newAsc = null;
    let newOrder = this.args.field;

    if (this.args.order === this.args.field) {
      newAsc = this.args.asc ? null : true;
    } else {
      newAsc = null;
    }

    this.args.onToggle?.(newOrder, newAsc);

    this._focusHeader();
  }

  _focusHeader() {
    schedule("afterRender", () => {
      document.getElementById(this.id)?.focus();
    });
  }

  @action
  click() {
    this.toggleProperties();
  }

  @action
  keyPress(event) {
    if (event.key === "Enter") {
      this.toggleProperties();
    }
  }

  <template>
    <div
      class={{concat "directory-table__column-header sortable " @class}}
      title={{@title}}
      colspan={{@colspan}}
      aria-sort={{this.ariaSort}}
      role="columnheader"
      {{! template-lint-disable no-invalid-interactive }}
      {{on "click" this.click}}
      {{! template-lint-disable no-invalid-interactive }}
      {{on "keypress" this.keyPress}}
    >
      <div
        class="header-contents"
        id={{this.id}}
        role="button"
        tabindex="0"
        aria-label={{this.ariaLabel}}
        aria-pressed={{this.pressedState}}
      >
        {{yield}}
        <span class="text">
          {{#if this.iconName}}
            {{dIcon this.iconName}}
          {{/if}}
          {{this.label}}
          {{#if this.chevronIcon}}
            {{dIcon this.chevronIcon}}
          {{/if}}
        </span>
      </div>
    </div>
  </template>
}
