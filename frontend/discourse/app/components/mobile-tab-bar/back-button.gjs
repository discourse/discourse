import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";

export default class MobileTabBarBackButton extends Component {
  @service mobileTabBar;

  <template>
    <DButton
      class="btn-flat mobile-tab-bar-back"
      @action={{this.mobileTabBar.goBack}}
      @ariaLabel="mobile_tab_bar.back"
      @icon="chevron-left"
      @title="mobile_tab_bar.back"
    />
  </template>
}
