/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed, set } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import concatClass from "discourse/helpers/concat-class";

@tagName("")
export default class AdminReportTableCell extends Component {
  options = null;

  @computed("label.type")
  get type() {
    return this.label?.type;
  }

  set type(value) {
    set(this, "label.type", value);
  }

  @computed("label.mainProperty")
  get property() {
    return this.label?.mainProperty;
  }

  set property(value) {
    set(this, "label.mainProperty", value);
  }

  @computed("computedLabel.formattedValue")
  get formattedValue() {
    return this.computedLabel?.formattedValue;
  }

  set formattedValue(value) {
    set(this, "computedLabel.formattedValue", value);
  }

  @computed("computedLabel.value")
  get value() {
    return this.computedLabel?.value;
  }

  set value(value) {
    set(this, "computedLabel.value", value);
  }

  @computed("label", "data", "options")
  get computedLabel() {
    return this.label.compute(this.data, this.options || {});
  }

  <template>
    <td
      title={{this.value}}
      class={{concatClass "admin-report-table-cell" this.type this.property}}
      ...attributes
    >
      {{htmlSafe this.formattedValue}}
    </td>
  </template>
}
