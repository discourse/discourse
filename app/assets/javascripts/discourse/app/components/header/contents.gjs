import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { throttle } from "@ember/runloop";
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
  @service sidebarState;

  @tracked viewportWidth;

  willDestroy() {
    super.willDestroy(...arguments);
    this.destroyListener();
  }

  @action
  updateWidth() {
    this.viewportWidth = window.innerWidth;
  }

  @action
  setupListener() {
    this.viewportWidth = window.innerWidth;

    this.resizeHandler = () => {
      throttle(this, this.updateWidth, 100);
    };

    window.addEventListener("resize", this.resizeHandler);
  }

  @action
  destroyListener() {
    window.removeEventListener("resize", this.resizeHandler);
  }

  get sidebarIcon() {
    if (this.sidebarState.adminSidebarAllowedWithLegacyNavigationMenu) {
      return "discourse-sidebar";
    }

    return "bars";
  }

  get minimized() {
    const shouldMinimize =
      this.args.topicInfoVisible &&
      !this.args.showSidebar &&
      this.viewportWidth <= 1200;

    return applyValueTransformer("home-logo-minimized", shouldMinimize, {
      topicInfo: this.args.topicInfo,
      sidebarEnabled: this.args.sidebarEnabled,
      showSidebar: this.args.showSidebar,
    });
  }

  get showHeaderSearch() {
    if (this.site.mobileView) {
      return false;
    }

    const searchExperience = applyValueTransformer(
      "site-setting-search-experience",
      this.siteSettings.search_experience
    );

    return searchExperience === "search_field" && !this.args.topicInfoVisible;
  }

  <template>
    <div class="contents">

      {{#if this.siteSettings.grid_layout}}
        {{bodyClass "grid-layout"}}
        <div
          class="d-header__contents-primary"
          {{didInsert this.setupListener}}
        >
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
