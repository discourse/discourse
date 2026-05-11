/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dNumber from "discourse/ui-kit/helpers/d-number";

@tagName("")
export default class AdminReportCounters extends Component {
  <template>
    <div
      title={{this.model.description}}
      class="admin-report-counters"
      ...attributes
    >
      <div class="cell title">
        {{#if this.model.icon}}
          {{dIcon this.model.icon}}
        {{/if}}
        <a href={{this.model.reportUrl}}>{{this.model.title}}</a>
      </div>

      <div class="cell value today-count">
        {{dNumber this.model.todayCount}}
      </div>

      <div
        class="cell value yesterday-count {{this.model.yesterdayTrend}}"
        title={{this.model.yesterdayCountTitle}}
      >
        {{dNumber this.model.yesterdayCount}}
        {{dIcon this.model.yesterdayTrendIcon}}
      </div>

      <div
        class="cell value sevendays-count {{this.model.sevenDaysTrend}}"
        title={{this.model.sevenDaysCountTitle}}
      >
        {{dNumber this.model.lastSevenDaysCount}}
        {{dIcon this.model.sevenDaysTrendIcon}}
      </div>

      <div
        class="cell value thirty-days-count {{this.model.thirtyDaysTrend}}"
        title={{this.model.thirtyDaysCountTitle}}
      >
        {{dNumber this.model.lastThirtyDaysCount}}

        {{#if this.model.canDisplayTrendIcon}}
          {{dIcon this.model.thirtyDaysTrendIcon}}
        {{/if}}
      </div>
    </div>
  </template>
}
