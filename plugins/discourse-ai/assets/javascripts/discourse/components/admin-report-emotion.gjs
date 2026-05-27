/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import getURL from "discourse/lib/get-url";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dNumber from "discourse/ui-kit/helpers/d-number";

@tagName("")
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
    return "%20order%3A" + this.model.type;
  }

  _filterURL(date) {
    return getURL(`${this._baseFilter()}${date}${this._model()}`);
  }

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
        {{this.model.title}}
      </div>

      <div class="cell value today-count">
        <a href={{this.todayLink}}>
          {{dNumber this.model.todayCount}}
        </a>
      </div>

      <div
        class="cell value yesterday-count {{this.model.yesterdayTrend}}"
        title={{this.model.yesterdayCountTitle}}
      >
        <a href={{this.yesterdayLink}}>
          {{dNumber this.model.yesterdayCount}}
        </a>
        {{dIcon this.model.yesterdayTrendIcon}}
      </div>

      <div
        class="cell value sevendays-count {{this.model.sevenDaysTrend}}"
        title={{this.model.sevenDaysCountTitle}}
      >
        <a href={{this.lastSevenDaysLink}}>
          {{dNumber this.model.lastSevenDaysCount}}
        </a>
        {{dIcon this.model.sevenDaysTrendIcon}}
      </div>

      <div
        class="cell value thirty-days-count {{this.model.thirtyDaysTrend}}"
        title={{this.model.thirtyDaysCountTitle}}
      >

        <a href={{this.lastThirtyDaysLink}}>
          {{dNumber this.model.lastThirtyDaysCount}}
        </a>
        {{#if this.model.canDisplayTrendIcon}}
          {{dIcon this.model.thirtyDaysTrendIcon}}
        {{/if}}
      </div>
    </div>
  </template>
}
