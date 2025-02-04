import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import { and } from "truth-helpers";
import deprecatedOutletArgument from "discourse/helpers/deprecated-outlet-argument";
import { applyValueTransformer } from "discourse/lib/transformer";
import BootstrapModeNotice from "../bootstrap-mode-notice";
import PluginOutlet from "../plugin-outlet";
import HomeLogo from "./home-logo";
import SidebarToggle from "./sidebar-toggle";
import TopicInfo from "./topic/info";

export default class Contents extends Component {
  @service site;
  @service currentUser;
  @service siteSettings;
  @service header;
  @service sidebarState;

  get sidebarIcon() {
    if (this.sidebarState.adminSidebarAllowedWithLegacyNavigationMenu) {
      return "discourse-sidebar";
    }

    return "bars";
  }

  get minimized() {
    return applyValueTransformer(
      "home-logo-minimized",
      this.args.topicInfoVisible,
      {
        topicInfo: this.args.topicInfo,
        sidebarEnabled: this.args.sidebarEnabled,
        showSidebar: this.args.showSidebar,
      }
    );
  }

  <template>
    <div class="contents">
      <PluginOutlet
        @name="header-contents__before"
        @outletArgs={{hash
          topicInfo=@topicInfo
          topicInfoVisible=@topicInfoVisible
        }}
        @deprecatedArgs={{hash
          topic=(deprecatedOutletArgument
            value=this.header.topic
            message="The argument 'topic' is deprecated on the outlet 'header-contents__before', use 'topicInfo' or 'topicInfoVisible' instead"
            id="discourse.plugin-connector.deprecated-arg.header-contents.topic"
            since="3.3.0.beta4-dev"
            dropFrom="3.4.0"
            silence="discourse.header-service-topic"
          )
        }}
      />
      {{#if this.site.desktopView}}
        {{#if @sidebarEnabled}}
          <SidebarToggle
            @toggleNavigationMenu={{@toggleNavigationMenu}}
            @showSidebar={{@showSidebar}}
            @icon={{this.sidebarIcon}}
          />
        {{/if}}
      {{/if}}

      <div class="home-logo-wrapper-outlet">
        <PluginOutlet @name="home-logo-wrapper">
          <HomeLogo @minimized={{this.minimized}} />
        </PluginOutlet>
      </div>

      {{#if @topicInfoVisible}}
        <TopicInfo @topicInfo={{@topicInfo}} />
      {{else if
        (and
          this.siteSettings.bootstrap_mode_enabled
          this.currentUser.staff
          this.site.desktopView
        )
      }}
        <div class="d-header-mode">
          <BootstrapModeNotice />
        </div>
      {{/if}}

      <div class="before-header-panel-outlet">
        <PluginOutlet
          @name="before-header-panel"
          @outletArgs={{hash
            topicInfo=@topicInfo
            topicInfoVisible=@topicInfoVisible
          }}
          @deprecatedArgs={{hash
            topic=(deprecatedOutletArgument
              value=this.header.topic
              message="The argument 'topic' is deprecated on the outlet 'before-header-panel', use 'topicInfo' or 'topicInfoVisible' instead"
              id="discourse.plugin-connector.deprecated-arg.header-contents.topic"
              since="3.3.0.beta4-dev"
              dropFrom="3.4.0"
              silence="discourse.header-service-topic"
            )
          }}
        />
      </div>
      <div class="panel" role="navigation">{{yield}}</div>
      <div class="after-header-panel-outlet">
        <PluginOutlet
          @name="after-header-panel"
          @outletArgs={{hash
            topicInfo=@topicInfo
            topicInfoVisible=@topicInfoVisible
          }}
          @deprecatedArgs={{hash
            topic=(deprecatedOutletArgument
              value=this.header.topic
              message="The argument 'topic' is deprecated on the outlet 'after-header-panel', use 'topicInfo' or 'topicInfoVisible' instead"
              id="discourse.plugin-connector.deprecated-arg.header-contents.topic"
              since="3.3.0.beta4-dev"
              dropFrom="3.4.0"
              silence="discourse.header-service-topic"
            )
          }}
        />
      </div>
      <PluginOutlet
        @name="header-contents__after"
        @outletArgs={{hash
          topicInfo=@topicInfo
          topicInfoVisible=@topicInfoVisible
        }}
        @deprecatedArgs={{hash
          topic=(deprecatedOutletArgument
            value=this.header.topic
            message="The argument 'topic' is deprecated on the outlet 'header-contents__after', use 'topicInfo' or 'topicInfoVisible' instead"
            id="discourse.plugin-connector.deprecated-arg.header-contents.topic"
            since="3.3.0.beta4-dev"
            dropFrom="3.4.0"
            silence="discourse.header-service-topic"
          )
        }}
      />
    </div>
  </template>
}
