import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class DiscoveryLayout extends Component {
  @service site;
  @service currentUser;
  @service siteSettings;

  get showLoadingSpinner() {
    return (
      this.args.loading &&
      this.siteSettings.page_loading_indicator === "spinner"
    );
  }
}
