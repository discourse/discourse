import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import {
  formatDeltaPercent,
  formatKpiValue,
} from "discourse/admin/lib/dashboard-format";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class KpiTile extends Component {
  get displayValue() {
    return formatKpiValue(this.args.type, this.args.value);
  }

  get label() {
    return i18n(`admin.dashboard.highlights.kpi.${this.args.type}.label`);
  }

  get tooltip() {
    return i18n(`admin.dashboard.highlights.kpi.${this.args.type}.tooltip`);
  }

  get hasDelta() {
    return this.args.percentChange != null;
  }

  get deltaClass() {
    return this.args.percentChange >= 0 ? "--pos" : "--neg";
  }

  get deltaText() {
    return formatDeltaPercent(this.args.percentChange);
  }

  get ariaLabel() {
    const parts = [this.label, this.displayValue];
    if (this.hasDelta) {
      const trend = this.args.comparisonLabel
        ? `${this.deltaText} ${this.args.comparisonLabel}`
        : this.deltaText;
      parts.push(trend);
    }
    return parts.join(", ");
  }

  get reportQuery() {
    return this.args.reportQuery ?? {};
  }

  @action
  stopPropagation(event) {
    // tooltip lives inside the LinkTo; without this, clicking the trigger
    // also navigates to the report
    event.stopPropagation();
  }

  <template>
    <LinkTo
      class="db-kpi db-section__row-block"
      @route="adminReports.show"
      @model={{@reportType}}
      @query={{hash
        start_date=this.reportQuery.start_date
        end_date=this.reportQuery.end_date
      }}
      aria-label={{this.ariaLabel}}
    >
      <div class="db-kpi__value">{{this.displayValue}}</div>
      <div class="db-kpi__label">
        {{this.label}}
        <DTooltip
          class="db-kpi__tooltip"
          @icon="far-circle-question"
          @content={{this.tooltip}}
          {{on "click" this.stopPropagation}}
        />
      </div>
      {{#if this.hasDelta}}
        <div
          class={{concat "db-delta " this.deltaClass}}
        >{{this.deltaText}}</div>
      {{/if}}
      <span class="db-link-arrow" aria-hidden="true">{{dIcon
          "arrow-right"
        }}</span>
    </LinkTo>
  </template>
}
