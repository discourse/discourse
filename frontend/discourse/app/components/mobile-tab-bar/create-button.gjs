import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";

export default class MobileTabBarCreateButton extends Component {
  @service mobileTabBar;

  get createActions() {
    return this.mobileTabBar.createActions;
  }

  get onlyAction() {
    return this.createActions.length === 1 ? this.createActions[0] : null;
  }

  @action
  run(createAction, menu) {
    menu?.close();
    this.mobileTabBar.closeMenu();
    createAction.action();
  }

  <template>
    {{#if this.onlyAction}}
      <DButton
        class="btn-primary mobile-tab-bar__create"
        @action={{fn this.run this.onlyAction null}}
        @icon="plus"
        @translatedAriaLabel={{this.onlyAction.label}}
      />
    {{else if this.createActions.length}}
      <DMenu
        @ariaLabel={{i18n "mobile_tab_bar.create"}}
        @icon="plus"
        @identifier="mobile-tab-bar-create"
        @modalForMobile={{true}}
        @triggerClass="btn-primary mobile-tab-bar__create"
      >
        <:content as |menu|>
          <DDropdownMenu as |dropdown|>
            {{#each this.createActions as |createAction|}}
              <dropdown.item>
                <DButton
                  class="btn-transparent mobile-tab-bar__create-action"
                  @action={{fn this.run createAction menu}}
                  @icon={{createAction.icon}}
                  @translatedLabel={{createAction.label}}
                />
              </dropdown.item>
            {{/each}}
          </DDropdownMenu>
        </:content>
      </DMenu>
    {{/if}}
  </template>
}
