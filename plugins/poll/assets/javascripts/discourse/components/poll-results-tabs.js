import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import I18n from "discourse-i18n";

const tabOne = I18n.t("poll.results.tabs.votes");
const tabTwo = I18n.t("poll.results.tabs.outcome");

export default class TabsComponent extends Component {
  @tracked activeTab = tabOne;

  constructor() {
    super(...arguments);
    this.tabOne = tabOne;
    this.tabTwo = tabTwo;
    this.activeTab =
      this.args.isIrv && this.args.isPublic ? this.tabs[1] : this.tabs[0];
  }
  get tabs() {
    let tabs = [];

    if (!this.args.isIrv || (this.args.isIrv && this.args.isPublic)) {
      tabs.push(tabOne);
    }

    if (this.args.isIrv) {
      tabs.push(tabTwo);
    }
    return tabs;
  }

  @action
  selectTab(tab) {
    this.activeTab = tab;
  }
}
