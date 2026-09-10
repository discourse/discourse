import Component from "@glimmer/component";
import getURL from "discourse/lib/get-url";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dNumber from "discourse/ui-kit/helpers/d-number";

export default class AdminReportEmotion extends Component {
  get todayLink() {
    let date = moment().format("YYYY-MM-DD");
    return this._filterURL(date);
  }

  get yesterdayLink() {
    let date = moment().subtract(1, "day").format("YYYY-MM-DD");
    return this._filterURL(date);
  }

  get lastSevenDaysLink() {
    let date = moment().subtract(1, "week").format("YYYY-MM-DD");
    return this._filterURL(date);
  }

  get lastThirtyDaysLink() {
    let date = moment().subtract(1, "month").format("YYYY-MM-DD");
    return this._filterURL(date);
  }

  _baseFilter() {
    return "/filter?q=activity-after%3A";
  }

  _model() {
    return "%20order%3A" + this.args.model.type;
  }

  _filterURL(date) {
    return getURL(`${this._baseFilter()}${date}${this._model()}`);
  }

  <template>
    <div
      class="admin-report-counters"
      title={{@model.description}}
      ...attributes
    >
      <div class="cell title">
        {{#if @model.icon}}
          {{dIcon @model.icon}}
        {{/if}}
        {{@model.title}}
      </div>

      <div class="cell value today-count">
        <a href={{this.todayLink}}>
          {{dNumber @model.todayCount}}
        </a>
      </div>

      <div
        class="cell value yesterday-count {{@model.yesterdayTrend}}"
        title={{@model.yesterdayCountTitle}}
      >
        <a href={{this.yesterdayLink}}>
          {{dNumber @model.yesterdayCount}}
        </a>
        {{dIcon @model.yesterdayTrendIcon}}
      </div>

      <div
        class="cell value sevendays-count {{@model.sevenDaysTrend}}"
        title={{@model.sevenDaysCountTitle}}
      >
        <a href={{this.lastSevenDaysLink}}>
          {{dNumber @model.lastSevenDaysCount}}
        </a>
        {{dIcon @model.sevenDaysTrendIcon}}
      </div>

      <div
        class="cell value thirty-days-count {{@model.thirtyDaysTrend}}"
        title={{@model.thirtyDaysCountTitle}}
      >

        <a href={{this.lastThirtyDaysLink}}>
          {{dNumber @model.lastThirtyDaysCount}}
        </a>
        {{#if @model.canDisplayTrendIcon}}
          {{dIcon @model.thirtyDaysTrendIcon}}
        {{/if}}
      </div>
    </div>
  </template>
}
