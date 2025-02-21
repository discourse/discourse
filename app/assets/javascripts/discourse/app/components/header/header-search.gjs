import Component from "@glimmer/component";
import { service } from "@ember/service";
import { modifier as modifierFn } from "ember-modifier";
import DButton from "discourse/components/d-button";
import SearchMenu, { focusSearchInput } from "discourse/components/search-menu";
import bodyClass from "discourse/helpers/body-class";
import concatClass from "discourse/helpers/concat-class";

export default class HeaderSearch extends Component {
  @service site;
  @service siteSettings;
  @service currentUser;
  @service appEvents;

  handleKeyboardShortcut = modifierFn(() => {
    const cb = () => focusSearchInput();
    this.appEvents.on("header:keyboard-trigger", cb);
    return () => this.appEvents.off("header:keyboard-trigger", cb);
  });

  get shouldDisplay() {
    return (
      (this.siteSettings.login_required && this.currentUser) ||
      !this.siteSettings.login_required
    );
  }

  get advancedSearchButtonHref() {
    return "/search?expanded=true";
  }

  <template>
    {{#if this.shouldDisplay}}
      {{bodyClass "search-header--visible"}}
      <div
        class="floating-search-input-wrapper"
        {{this.handleKeyboardShortcut}}
      >
        <div class="floating-search-input">
          <div class="search-banner">
            <div class="search-banner-inner wrap">
              <div class="search-menu">
                <DButton
                  @icon="magnifying-glass"
                  @translatedLabel={{@buttonText}}
                  @title="search.open_advanced"
                  class={{concatClass "btn search-icon" @buttonClass}}
                  @href={{this.advancedSearchButtonHref}}
                />

                <SearchMenu />
              </div>
            </div>
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
