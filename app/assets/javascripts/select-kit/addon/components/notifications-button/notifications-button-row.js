import { computed } from "@ember/object";
import { readOnly } from "@ember/object/computed";
import { classNames } from "@ember-decorators/component";
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import DropdownSelectBoxRowComponent from "select-kit/components/dropdown-select-box/dropdown-select-box-row";

@classNames("notifications-button-row")
export default class NotificationsButtonRow extends DropdownSelectBoxRowComponent {
  @readOnly("selectKit.options.i18nPrefix") i18nPrefix;
  @readOnly("selectKit.options.i18nPostfix") i18nPostfix;

  @computed("_start")
  get label() {
    return escapeExpression(i18n(`${this._start}.title`));
  }

  @computed("item.icon")
  get icons() {
    return [escapeExpression(this.item.icon)];
  }

  @computed("_start")
  get description() {
    return escapeExpression(i18n(`${this._start}.description`));
  }

  @computed("i18nPrefix", "i18nPostfix", "rowName")
  get _start() {
    return `${this.i18nPrefix}.${this.rowName}${this.i18nPostfix}`;
  }
}
