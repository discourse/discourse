import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { escapeExpression } from "discourse/lib/utilities";
import DropdownSelectBoxRowComponent from "discourse/select-kit/components/dropdown-select-box/dropdown-select-box-row";
import { i18n } from "discourse-i18n";

@classNames("notifications-button-row")
export default class NotificationsButtonRow extends DropdownSelectBoxRowComponent {
  @computed("selectKit.options.i18nPrefix")
  get i18nPrefix() {
    return this.selectKit?.options?.i18nPrefix;
  }

  @computed("selectKit.options.i18nPostfix")
  get i18nPostfix() {
    return this.selectKit?.options?.i18nPostfix;
  }

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
