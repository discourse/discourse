/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import number from "discourse/helpers/number";

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
          {{icon this.model.icon}}
        {{/if}}
        <a href={{this.model.reportUrl}}>{{this.model.title}}</a>
      </div>

      <div class="cell value today-count">
        {{number this.model.todayCount}}
      </div>

      <div
        class="cell value yesterday-count {{this.model.yesterdayTrend}}"
        title={{this.model.yesterdayCountTitle}}
      >
        {{number this.model.yesterdayCount}}
        {{icon this.model.yesterdayTrendIcon}}
      </div>

      <div
        class="cell value sevendays-count {{this.model.sevenDaysTrend}}"
        title={{this.model.sevenDaysCountTitle}}
      >
        {{number this.model.lastSevenDaysCount}}
        {{icon this.model.sevenDaysTrendIcon}}
      </div>

      <div
        class="cell value thirty-days-count {{this.model.thirtyDaysTrend}}"
        title={{this.model.thirtyDaysCountTitle}}
      >
        {{number this.model.lastThirtyDaysCount}}

        {{#if this.model.canDisplayTrendIcon}}
          {{icon this.model.thirtyDaysTrendIcon}}
        {{/if}}
      </div>
    </div>
  </template>
}
