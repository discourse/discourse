/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed, set } from "@ember/object";
import { trustHTML } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import AdminReportTableSummary from "discourse/admin/components/admin-report-table-summary";
import { adminReportRelatedItemsRenderer } from "discourse/admin/lib/admin-report-related-items";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

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

  @computed("hasRelatedItems", "type", "property", "value")
  get hasRelatedItemsSummary() {
    return (
      this.hasRelatedItems &&
      this.type === "number" &&
      this.property === "y" &&
      this.value > 0
    );
  }

  @computed("reportType")
  get relatedItemsRenderer() {
    return adminReportRelatedItemsRenderer(this.reportType);
  }

  @computed("reportType")
  get relatedItemsSummaryComponent() {
    return this.relatedItemsRenderer?.tableSummaryComponent;
  }

  <template>
    <td
      title={{if this.hasRelatedItemsSummary null this.value}}
      class={{dConcatClass "admin-report-table-cell" this.type this.property}}
      ...attributes
    >
      {{#if this.hasRelatedItemsSummary}}
        {{#if this.relatedItemsRenderer}}
          {{#if this.relatedItemsSummaryComponent}}
            {{component
              this.relatedItemsSummaryComponent
              date=this.data.x
              formattedValue=this.formattedValue
              reportFilters=this.reportFilters
            }}
          {{else}}
            {{trustHTML this.formattedValue}}
          {{/if}}
        {{else}}
          <AdminReportTableSummary
            @date={{this.data.x}}
            @formattedValue={{this.formattedValue}}
            @reportType={{this.reportType}}
            @reportFilters={{this.reportFilters}}
          />
        {{/if}}
      {{else}}
        {{trustHTML this.formattedValue}}
      {{/if}}
    </td>
  </template>
}
