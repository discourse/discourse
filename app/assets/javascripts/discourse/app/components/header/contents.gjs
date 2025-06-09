import Component from "@glimmer/component";
import { service } from "@ember/service";
import bodyClass from "discourse/helpers/body-class";
import { applyValueTransformer } from "discourse/lib/transformer";
import ContentsPrimary from "./contents-primary";
import ContentsSecondary from "./contents-secondary";

export default class Contents extends Component {
  @service site;
  @service currentUser;
  @service siteSettings;
  @service header;
  @service router;
  @service navigationMenu;
  @service search;
  @service capabilities;

  get sidebarIcon() {
    if (this.navigationMenu.isDesktopDropdownMode) {
      return "discourse-sidebar";
    }

    return "bars";
  }

  get minimized() {
    const minimizeForGrid =
      this.siteSettings.grid_layout && !this.capabilities.viewport["2xl"];

    const shouldMinimize =
      this.args.topicInfoVisible && !this.args.showSidebar && minimizeForGrid;

    return applyValueTransformer("home-logo-minimized", shouldMinimize, {
      topicInfo: this.args.topicInfo,
      sidebarEnabled: this.args.sidebarEnabled,
      showSidebar: this.args.showSidebar,
    });
  }

  get showHeaderSearch() {
    if (
      this.site.mobileView ||
      this.args.narrowDesktop ||
      this.router.currentURL?.match(
        /\/(signup|login|invites|activate-account)/
      ) ||
      this.search.welcomeBannerSearchInViewport
    ) {
      return false;
    }

    if (
      this.search.searchExperience === "search_field" &&
      !this.args.topicInfoVisible &&
      !this.search.welcomeBannerSearchInViewport
    ) {
      return true;
    }
  }

  <template>
    <div class="contents {{if this.args.topicInfoVisible '--title-docked'}}">
      {{#if this.siteSettings.grid_layout}}
        {{bodyClass "grid-layout"}}
        <div class="d-header__contents-primary">
          <ContentsPrimary
            @topicInfo={{@topicInfo}}
            @topicInfoVisible={{@topicInfoVisible}}
            @headerTopic={{this.header.topic}}
            @desktopView={{this.site.desktopView}}
            @sidebarEnabled={{@sidebarEnabled}}
            @toggleNavigationMenu={{@toggleNavigationMenu}}
            @showSidebar={{@showSidebar}}
            @sidebarIcon={{this.sidebarIcon}}
            @minimized={{this.minimized}}
          />
        </div>
        <div class="d-header__contents-secondary">
          <ContentsSecondary
            @topicInfo={{@topicInfo}}
            @topicInfoVisible={{@topicInfoVisible}}
            @headerTopic={{this.header.topic}}
            @bootstrapEnabled={{this.siteSettings.bootstrap_mode_enabled}}
            @isStaff={{this.currentUser.staff}}
            @desktopView={{this.site.desktopView}}
            @showHeaderSearch={{this.showHeaderSearch}}
          >
            {{yield}}
          </ContentsSecondary>
        </div>
      {{else}}
        <ContentsPrimary
          @topicInfo={{@topicInfo}}
          @topicInfoVisible={{@topicInfoVisible}}
          @headerTopic={{this.header.topic}}
          @desktopView={{this.site.desktopView}}
          @sidebarEnabled={{@sidebarEnabled}}
          @toggleNavigationMenu={{@toggleNavigationMenu}}
          @showSidebar={{@showSidebar}}
          @sidebarIcon={{this.sidebarIcon}}
          @minimized={{this.minimized}}
        />
        <ContentsSecondary
          @topicInfo={{@topicInfo}}
          @topicInfoVisible={{@topicInfoVisible}}
          @headerTopic={{this.header.topic}}
          @bootstrapEnabled={{this.siteSettings.bootstrap_mode_enabled}}
          @isStaff={{this.currentUser.staff}}
          @desktopView={{this.site.desktopView}}
        >
          {{yield}}
        </ContentsSecondary>
      {{/if}}
    </div>
  </template>
}
