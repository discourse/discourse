import Component from "@glimmer/component";
import { service } from "@ember/service";
import PageShellRegion from "discourse/components/page-shell/region";
import { ALL_PAGES_EXCLUDED_ROUTES } from "discourse/components/welcome-banner";
import deprecatedOutletArgument from "discourse/helpers/deprecated-outlet-argument";
import lazyHash from "discourse/helpers/lazy-hash";
import { applyValueTransformer } from "discourse/lib/transformer";
import DNativeSelect from "discourse/ui-kit/d-native-select";
import { i18n } from "discourse-i18n";
import PluginOutlet from "../plugin-outlet.gjs";
import HeaderSearch from "./header-search.gjs";
import HomeLogo from "./home-logo.gjs";
import SidebarToggle from "./sidebar-toggle.gjs";
import TopicInfo from "./topic/info.gjs";

export default class Contents extends Component {
  @service site;
  @service pageShell;
  @service header;
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
    // Applied after the transformer: the full logo does not fit at all.
    return (
      this.pageShell.compactLogo ||
      applyValueTransformer("home-logo-minimized", this.args.topicInfoVisible, {
        topicInfo: this.args.topicInfo,
        sidebarEnabled: this.args.sidebarEnabled,
        showSidebar: this.args.showSidebar,
      })
    );
  }

  get visibleTopic() {
    return this.header.topicInfoVisible ? this.header.topicInfo : null;
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
            value=this.visibleTopic
            message="The argument 'topic' is deprecated on the outlet 'header-contents__before', use 'topicInfo' or 'topicInfoVisible' instead"
            id="discourse.plugin-connector.deprecated-arg.header-contents.topic"
            since="3.3.0.beta4-dev"
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
      <PageShellRegion
        class="page-shell__header-start"
        @enabled={{this.pageShell.enabled}}
      >
        {{#if this.site.desktopView}}
          {{#if @sidebarEnabled}}
            <SidebarToggle
              @icon={{if this.pageShell.enabled "bars" this.sidebarIcon}}
              @showSidebar={{@showSidebar}}
              @toggleNavigationMenu={{@toggleNavigationMenu}}
            />
          {{/if}}
        {{/if}}

        <div class="home-logo-wrapper-outlet">
          <PluginOutlet @name="home-logo-wrapper">
            <HomeLogo @minimized={{this.minimized}} />
          </PluginOutlet>
        </div>

      </PageShellRegion>

      {{#if
        (and
          this.pageShell.enabled
          this.pageShell.hasContextPanel
          (or
            (eq this.pageShell.context "open")
            this.pageShell.closingPanels.context
          )
        )
      }}
        <div
          class="page-shell__header-context"
          inert={{if this.pageShell.closingPanels.context true}}
        >
          <DNativeSelect
            aria-label={{i18n "page_shell.context_view"}}
            @includeNone={{false}}
            @value="overview"
            as |select|
          >
            <select.Option @value="overview">
              {{i18n "page_shell.context_overview"}}
            </select.Option>
          </DNativeSelect>
        </div>
      {{/if}}

      <PageShellRegion
        class="page-shell__header-main"
        @enabled={{this.pageShell.enabled}}
      >
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
                value=this.visibleTopic
                message="The argument 'topic' is deprecated on the outlet 'before-header-panel', use 'topicInfo' or 'topicInfoVisible' instead"
                id="discourse.plugin-connector.deprecated-arg.header-contents.topic"
                since="3.3.0.beta4-dev"
              )
            }}
            @name="before-header-panel"
            @outletArgs={{lazyHash
              topicInfo=@topicInfo
              topicInfoVisible=@topicInfoVisible
            }}
          />
        </div>
      </PageShellRegion>
      <div
        aria-label={{i18n "header_panel"}}
        class="panel"
        role="navigation"
      >{{yield}}</div>
      <div class="after-header-panel-outlet">
        <PluginOutlet
          @deprecatedArgs={{lazyHash
            topic=(deprecatedOutletArgument
              value=this.visibleTopic
              message="The argument 'topic' is deprecated on the outlet 'after-header-panel', use 'topicInfo' or 'topicInfoVisible' instead"
              id="discourse.plugin-connector.deprecated-arg.header-contents.topic"
              since="3.3.0.beta4-dev"
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
            value=this.visibleTopic
            message="The argument 'topic' is deprecated on the outlet 'header-contents__after', use 'topicInfo' or 'topicInfoVisible' instead"
            id="discourse.plugin-connector.deprecated-arg.header-contents.topic"
            since="3.3.0.beta4-dev"
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
