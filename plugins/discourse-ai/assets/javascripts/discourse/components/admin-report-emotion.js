import Component from "@ember/component";
import { attributeBindings, classNames } from "@ember-decorators/component";
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
}
