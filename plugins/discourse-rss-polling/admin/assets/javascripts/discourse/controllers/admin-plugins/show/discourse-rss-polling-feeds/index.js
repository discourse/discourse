import Controller from "@ember/controller";
import { action } from "@ember/object";
import { removeValueFromArray } from "discourse/lib/array-tools";

export default class AdminPluginsShowDiscourseRssPollingFeedsIndexController extends Controller {
  get feeds() {
    return this.model;
  }

  @action
  deleteFeed(feed) {
    removeValueFromArray(this.model, feed);
  }
}
