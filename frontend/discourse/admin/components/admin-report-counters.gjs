import dIcon from "discourse/ui-kit/helpers/d-icon";
import dNumber from "discourse/ui-kit/helpers/d-number";

const AdminReportCounters = <template>
  <div class="admin-report-counters" title={{@model.description}} ...attributes>
    <div class="cell title">
      {{#if @model.icon}}
        {{dIcon @model.icon}}
      {{/if}}
      <a href={{@model.reportUrl}}>{{@model.title}}</a>
    </div>

    <div class="cell value today-count">
      {{dNumber @model.todayCount}}
    </div>

    <div
      class="cell value yesterday-count {{@model.yesterdayTrend}}"
      title={{@model.yesterdayCountTitle}}
    >
      {{dNumber @model.yesterdayCount}}
      {{dIcon @model.yesterdayTrendIcon}}
    </div>

    <div
      class="cell value sevendays-count {{@model.sevenDaysTrend}}"
      title={{@model.sevenDaysCountTitle}}
    >
      {{dNumber @model.lastSevenDaysCount}}
      {{dIcon @model.sevenDaysTrendIcon}}
    </div>

    <div
      class="cell value thirty-days-count {{@model.thirtyDaysTrend}}"
      title={{@model.thirtyDaysCountTitle}}
    >
      {{dNumber @model.lastThirtyDaysCount}}

      {{#if @model.canDisplayTrendIcon}}
        {{dIcon @model.thirtyDaysTrendIcon}}
      {{/if}}
    </div>
  </div>
</template>;

export default AdminReportCounters;
