import Component from "@glimmer/component";
import { service } from "@ember/service";
import MobileTabBarBackButton from "discourse/components/mobile-tab-bar/back-button";
import { ALL_PAGES_EXCLUDED_ROUTES } from "discourse/components/welcome-banner";
import deprecatedOutletArgument from "discourse/helpers/deprecated-outlet-argument";
import lazyHash from "discourse/helpers/lazy-hash";
import { applyValueTransformer } from "discourse/lib/transformer";
import { i18n } from "discourse-i18n";
import PluginOutlet from "../plugin-outlet.gjs";
import HeaderSearch from "./header-search.gjs";
import HomeLogo from "./home-logo.gjs";
import SidebarToggle from "./sidebar-toggle.gjs";
import TopicInfo from "./topic/info.gjs";

export default class Contents extends Component {
  @service site;
  @service header;
  @service mobileTabBar;
  @service documentTitle;
  @service router;
  @service navigationMenu;
  @service search;

  get sidebarIcon() {
    if (this.navigationMenu.isDesktopDropdownMode) {
      return "discourse-sidebar";
    }

    return "bars";
  }

  get minimized() {
    // Below a section's top level, the logo makes room for the back button
    return applyValueTransformer(
      "home-logo-minimized",
      this.args.topicInfoVisible || this.mobileTabBar.isNestedPage,
      {
        topicInfo: this.args.topicInfo,
        sidebarEnabled: this.args.sidebarEnabled,
        showSidebar: this.args.showSidebar,
      }
    );
  }

  // A titled page names itself in the header unless it has a topic to show
  get pageTitle() {
    if (this.mobileTabBar.isTitledPage && !this.args.topicInfo) {
      return this.documentTitle.pageTitle;
    }
  }

  get showHeaderSearch() {
    if (
      !this.site.can_search ||
      this.site.mobileView ||
      this.args.narrowDesktop ||
      ALL_PAGES_EXCLUDED_ROUTES.some(
        (name) => name === this.router.currentRouteName
      ) ||
      this.search.welcomeBannerSearchInViewport ||
      this.router.currentRouteName.startsWith("admin")
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
    <div class="contents">
      <PluginOutlet
        @deprecatedArgs={{lazyHash
          topic=(deprecatedOutletArgument
            value=this.header.topic
            message="The argument 'topic' is deprecated on the outlet 'header-contents__before', use 'topicInfo' or 'topicInfoVisible' instead"
            id="discourse.plugin-connector.deprecated-arg.header-contents.topic"
            since="3.3.0.beta4-dev"
            silence="discourse.header-service-topic"
          )
        }}
        @name="header-contents__before"
        @outletArgs={{lazyHash
          topicInfo=@topicInfo
          topicInfoVisible=@topicInfoVisible
          toggleNavigationMenu=@toggleNavigationMenu
          showSidebar=@showSidebar
          sidebarIcon=this.sidebarIcon
        }}
      />
      {{#if this.site.desktopView}}
        {{#if @sidebarEnabled}}
          <SidebarToggle
            @icon={{this.sidebarIcon}}
            @showSidebar={{@showSidebar}}
            @toggleNavigationMenu={{@toggleNavigationMenu}}
          />
        {{/if}}
      {{else if this.mobileTabBar.isNestedPage}}
        <MobileTabBarBackButton />
      {{/if}}

      <div class="home-logo-wrapper-outlet">
        <PluginOutlet @name="home-logo-wrapper">
          {{#if this.pageTitle}}
            <h1 class="mobile-tab-bar-title">{{this.pageTitle}}</h1>
          {{else}}
            <HomeLogo @minimized={{this.minimized}} />
          {{/if}}
        </PluginOutlet>
      </div>

      {{#if @topicInfoVisible}}
        <TopicInfo @topicInfo={{@topicInfo}} />
      {{/if}}

      {{#if this.showHeaderSearch}}
        <HeaderSearch />
      {{/if}}

      <div class="before-header-panel-outlet">
        <PluginOutlet
          @deprecatedArgs={{lazyHash
            topic=(deprecatedOutletArgument
              value=this.header.topic
              message="The argument 'topic' is deprecated on the outlet 'before-header-panel', use 'topicInfo' or 'topicInfoVisible' instead"
              id="discourse.plugin-connector.deprecated-arg.header-contents.topic"
              since="3.3.0.beta4-dev"
              silence="discourse.header-service-topic"
            )
          }}
          @name="before-header-panel"
          @outletArgs={{lazyHash
            topicInfo=@topicInfo
            topicInfoVisible=@topicInfoVisible
          }}
        />
      </div>
      <div
        aria-label={{i18n "header_panel"}}
        class="panel"
        role="navigation"
      >{{yield}}</div>
      <div class="after-header-panel-outlet">
        <PluginOutlet
          @deprecatedArgs={{lazyHash
            topic=(deprecatedOutletArgument
              value=this.header.topic
              message="The argument 'topic' is deprecated on the outlet 'after-header-panel', use 'topicInfo' or 'topicInfoVisible' instead"
              id="discourse.plugin-connector.deprecated-arg.header-contents.topic"
              since="3.3.0.beta4-dev"
              silence="discourse.header-service-topic"
            )
          }}
          @name="after-header-panel"
          @outletArgs={{lazyHash
            topicInfo=@topicInfo
            topicInfoVisible=@topicInfoVisible
          }}
        />
      </div>
      <PluginOutlet
        @deprecatedArgs={{lazyHash
          topic=(deprecatedOutletArgument
            value=this.header.topic
            message="The argument 'topic' is deprecated on the outlet 'header-contents__after', use 'topicInfo' or 'topicInfoVisible' instead"
            id="discourse.plugin-connector.deprecated-arg.header-contents.topic"
            since="3.3.0.beta4-dev"
            silence="discourse.header-service-topic"
          )
        }}
        @name="header-contents__after"
        @outletArgs={{lazyHash
          topicInfo=@topicInfo
          topicInfoVisible=@topicInfoVisible
        }}
      />
    </div>
  </template>
}
