import Component from "@ember/component";
import { action } from "@ember/object";
import LoadMore from "discourse/mixins/load-more";

export default class LoadMoreComponent extends Component.extend(LoadMore) {
  init() {
    super.init(...arguments);

    this.set("eyelineSelector", this.selector);
  }

  @action
  loadMore() {
    this.action();
  }
}
