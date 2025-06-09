import deprecatedOutletArgument from "discourse/helpers/deprecated-outlet-argument";
import lazyHash from "discourse/helpers/lazy-hash";
import PluginOutlet from "../plugin-outlet";
import HomeLogo from "./home-logo";
import SidebarToggle from "./sidebar-toggle";

const ContentsPrimary = <template>
  <PluginOutlet
    @name="header-contents__before"
    @outletArgs={{lazyHash
      topicInfo=@topicInfo
      topicInfoVisible=@topicInfoVisible
    }}
    @deprecatedArgs={{lazyHash
      topic=(deprecatedOutletArgument
        value=@headerTopic
        message="The argument 'topic' is deprecated on the outlet 'header-contents__before', use 'topicInfo' or 'topicInfoVisible' instead"
        id="discourse.plugin-connector.deprecated-arg.header-contents.topic"
        since="3.3.0.beta4-dev"
        dropFrom="3.4.0"
        silence="discourse.header-service-topic"
      )
    }}
  />
  {{#if @desktopView}}
    {{#if @sidebarEnabled}}
      <SidebarToggle
        @toggleNavigationMenu={{@toggleNavigationMenu}}
        @showSidebar={{@showSidebar}}
        @icon={{@sidebarIcon}}
      />
    {{/if}}
  {{/if}}

  <div class="home-logo-wrapper-outlet">
    <PluginOutlet @name="home-logo-wrapper">
      <HomeLogo @minimized={{@minimized}} />
    </PluginOutlet>
  </div>
</template>;

export default ContentsPrimary;
