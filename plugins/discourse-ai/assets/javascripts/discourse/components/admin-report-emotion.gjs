import Component from "@ember/component";
import { attributeBindings, classNames } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import number from "discourse/helpers/number";
import getURL from "discourse/lib/get-url";

@classNames("admin-report-counters")
@attributeBindings("model.description:title")
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
    <div class="cell title">
      {{#if this.model.icon}}
        {{icon this.model.icon}}
      {{/if}}
      {{this.model.title}}
    </div>

    <div class="cell value today-count">
      <a href={{this.todayLink}}>
        {{number this.model.todayCount}}
      </a>
    </div>

    <div
      class="cell value yesterday-count {{this.model.yesterdayTrend}}"
      title={{this.model.yesterdayCountTitle}}
    >
      <a href={{this.yesterdayLink}}>
        {{number this.model.yesterdayCount}}
      </a>
      {{icon this.model.yesterdayTrendIcon}}
    </div>

    <div
      class="cell value sevendays-count {{this.model.sevenDaysTrend}}"
      title={{this.model.sevenDaysCountTitle}}
    >
      <a href={{this.lastSevenDaysLink}}>
        {{number this.model.lastSevenDaysCount}}
      </a>
      {{icon this.model.sevenDaysTrendIcon}}
    </div>

    <div
      class="cell value thirty-days-count {{this.model.thirtyDaysTrend}}"
      title={{this.model.thirtyDaysCountTitle}}
    >

      <a href={{this.lastThirtyDaysLink}}>
        {{number this.model.lastThirtyDaysCount}}
      </a>
      {{#if this.model.canDisplayTrendIcon}}
        {{icon this.model.thirtyDaysTrendIcon}}
      {{/if}}
    </div>
  </template>
}
