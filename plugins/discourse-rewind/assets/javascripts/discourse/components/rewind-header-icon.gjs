import Component from "@glimmer/component";
import { array, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import RewindHeader from "discourse/plugins/discourse-rewind/discourse/components/reports/header";

export default class RewindHeaderIcon extends Component {
  @service rewind;
  @service router;

  constructor() {
    super(...arguments);
    this.router.on("routeWillChange", this.closeTooltip);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.router.off("routeWillChange", this.closeTooltip);
  }

  get href() {
    return getURL("/my/activity/rewind");
  }

  get title() {
    return i18n("discourse_rewind.header_tooltip.title", {
      rewindYear: this.rewind.fetchRewindYear,
    });
  }

  get shouldDisplay() {
    return this.rewind.dismissed && !this.rewind.disabled;
  }

  get preferencesUrl() {
    return getURL("/my/preferences/rewind");
  }

  @action
  registerTooltip(tooltipInstance) {
    this.tooltipInstance = tooltipInstance;
  }

  @action
  closeTooltip() {
    this.tooltipInstance?.close();
  }

  <template>
    {{#if this.shouldDisplay}}
      <li class="header-dropdown-toggle rewind-header-icon">
        <DTooltip
          @identifier="rewind-header-icon-tooltip"
          @triggers={{hash mobile=(array "click") desktop=(array "click")}}
          @onRegisterApi={{this.registerTooltip}}
        >
          <:trigger>
            <DButton
              tabindex="0"
              class={{concatClass "icon" "btn-flat"}}
              title={{this.title}}
            >
              {{~icon "backward-fast"~}}
            </DButton>
          </:trigger>
          <:content>
            <RewindHeader />

            <p>{{i18n
                "discourse_rewind.header_tooltip.description"
                rewindYear=this.rewind.fetchRewindYear
                nextYear=this.rewind.fetchRewindNextYear
              }}</p>
            <DButton
              @href={{this.href}}
              class="rewind-header-icon__button btn-primary"
            >
              {{i18n "discourse_rewind.header_tooltip.take_me_there"}}
            </DButton>

            <p class="rewind-header-icon__preferences">
              {{htmlSafe
                (i18n
                  "discourse_rewind.header_tooltip.preferences_link"
                  preferencesUrl=this.preferencesUrl
                )
              }}</p>
          </:content>
        </DTooltip>
      </li>
    {{/if}}
  </template>
}
