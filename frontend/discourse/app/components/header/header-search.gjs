import Component from "@glimmer/component";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import SearchMenu from "discourse/components/search-menu";
import bodyClass from "discourse/helpers/body-class";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class HeaderSearch extends Component {
  @service siteSettings;
  @service currentUser;
  @service appEvents;
  @service search;

  advancedSearchButtonHref = "/search?expanded=true";

  handleKeyboardShortcut = modifier(() => {
    const cb = (appEvent) => {
      if (appEvent.type === "search") {
        this.search.focusSearchInput();
        appEvent.event.preventDefault();
      }
    };
    this.appEvents.on("header:keyboard-trigger", cb);
    return () => this.appEvents.off("header:keyboard-trigger", cb);
  });

  get shouldDisplay() {
    return (
      (this.siteSettings.login_required && this.currentUser) ||
      !this.siteSettings.login_required
    );
  }

  <template>
    {{#if this.shouldDisplay}}
      {{bodyClass "header-search--enabled"}}
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
                  class={{dConcatClass "btn search-icon" @buttonClass}}
                  @href={{this.advancedSearchButtonHref}}
                />

                <SearchMenu
                  @location="header"
                  @searchInputId="header-search-input"
                />
              </div>
            </div>
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
