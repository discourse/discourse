import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { trustHTML } from "@ember/template";
import AdminReportTableSummary from "discourse/admin/components/admin-report-table-summary";
import { adminReportRelatedItemsRenderer } from "discourse/admin/lib/admin-report-related-items";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class AdminReportTableCell extends Component {
  get type() {
    return this.args.label?.type;
  }

  get property() {
    return this.args.label?.mainProperty;
  }

  get formattedValue() {
    return this.computedLabel?.formattedValue;
  }

  get value() {
    return this.computedLabel?.value;
  }

  @cached
  get computedLabel() {
    return this.args.label.compute(this.args.data, this.args.options || {});
  }

  get hasRelatedItemsSummary() {
    return (
      this.args.hasRelatedItems &&
      this.type === "number" &&
      this.property === "y" &&
      this.value > 0
    );
  }

  get relatedItemsRenderer() {
    return adminReportRelatedItemsRenderer(this.args.reportType);
  }

  get relatedItemsSummary() {
    return this.relatedItemsRenderer?.tableSummary;
  }

  <template>
    <td
      class={{dConcatClass "admin-report-table-cell" this.type this.property}}
      title={{if this.hasRelatedItemsSummary null this.value}}
      ...attributes
    >
      {{#if this.hasRelatedItemsSummary}}
        {{#if this.relatedItemsRenderer}}
          {{#if this.relatedItemsSummary}}
            <AdminReportTableSummary
              @date={{@data.x}}
              @formattedValue={{this.formattedValue}}
              @itemComponent={{this.relatedItemsSummary.itemComponent}}
              @itemsKey={{this.relatedItemsSummary.itemsKey}}
              @listClass={{this.relatedItemsSummary.listClass}}
              @reportFilters={{@reportFilters}}
              @reportType={{@reportType}}
              @titleKey={{this.relatedItemsSummary.titleKey}}
            />
          {{else}}
            {{trustHTML this.formattedValue}}
          {{/if}}
        {{else}}
          <AdminReportTableSummary
            @date={{@data.x}}
            @formattedValue={{this.formattedValue}}
            @reportFilters={{@reportFilters}}
            @reportType={{@reportType}}
          />
        {{/if}}
      {{else}}
        {{trustHTML this.formattedValue}}
      {{/if}}
    </td>
  </template>
}
