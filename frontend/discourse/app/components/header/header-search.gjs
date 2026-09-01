import Component from "@glimmer/component";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import SearchMenu from "discourse/components/search-menu";
import bodyClass from "discourse/helpers/body-class";
import { applyValueTransformer } from "discourse/lib/transformer";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class HeaderSearch extends Component {
  @service siteSettings;
  @service currentUser;
  @service appEvents;
  @service search;

  advancedSearchButtonHref = "/search?expanded=true";

  // The icon is a shortcut to advanced search; a consumer that has made the
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

  // input mean more than searching can drop it.
  get showAdvancedSearchIcon() {
    return applyValueTransformer("search-advanced-icon-enabled", true, {
      location: "header",
    });
  }

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
                {{#if this.showAdvancedSearchIcon}}
                  <DButton
                    class={{dConcatClass "btn search-icon" @buttonClass}}
                    @href={{this.advancedSearchButtonHref}}
                    @icon="magnifying-glass"
                    @title="search.open_advanced"
                    @translatedLabel={{@buttonText}}
                  />
                {{/if}}

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
