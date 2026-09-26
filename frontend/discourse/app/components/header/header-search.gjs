import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import SearchMenu from "discourse/components/lazy/search-menu";
import bodyClass from "discourse/helpers/body-class";
import { service } from "discourse/lib/service";
import { applyValueTransformer } from "discourse/lib/transformer";
import AppEventsService from "discourse/services/app-events";
import CurrentUserService from "discourse/services/current-user";
import SearchService from "discourse/services/search";
import SiteService from "discourse/services/site";
import SiteSettingsService from "discourse/services/site-settings";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class HeaderSearch extends Component {
  @service(() => SiteService) site;
  @service(() => SiteSettingsService) siteSettings;
  @service(() => CurrentUserService) currentUser;
  @service(() => AppEventsService) appEvents;
  @service(() => SearchService) search;

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
      this.site.can_search &&
      ((this.siteSettings.login_required && this.currentUser) ||
        !this.siteSettings.login_required)
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
