import { and } from "truth-helpers";
import deprecatedOutletArgument from "discourse/helpers/deprecated-outlet-argument";
import lazyHash from "discourse/helpers/lazy-hash";
import BootstrapModeNotice from "../bootstrap-mode-notice";
import PluginOutlet from "../plugin-outlet";
import HeaderSearch from "./header-search";
import TopicInfo from "./topic/info";

const ContentsSecondary = <template>
  {{#if @topicInfoVisible}}
    <TopicInfo @topicInfo={{@topicInfo}} />
  {{else if (and @bootStrapEnabled @isStaff @desktopView)}}
    <div class="d-header-mode">
      <BootstrapModeNotice />
    </div>
  {{/if}}

  {{#if @showHeaderSearch}}
    <HeaderSearch />
  {{/if}}

  <div class="before-header-panel-outlet">
    <PluginOutlet
      @name="before-header-panel"
      @outletArgs={{lazyHash
        topicInfo=@topicInfo
        topicInfoVisible=@topicInfoVisible
      }}
      @deprecatedArgs={{lazyHash
        topic=(deprecatedOutletArgument
          value=@headerTopic
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
      @outletArgs={{lazyHash
        topicInfo=@topicInfo
        topicInfoVisible=@topicInfoVisible
      }}
      @deprecatedArgs={{lazyHash
        topic=(deprecatedOutletArgument
          value=@headerTopic
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
    @outletArgs={{lazyHash
      topicInfo=@topicInfo
      topicInfoVisible=@topicInfoVisible
    }}
    @deprecatedArgs={{lazyHash
      topic=(deprecatedOutletArgument
        value=@headerTopic
        message="The argument 'topic' is deprecated on the outlet 'header-contents__after', use 'topicInfo' or 'topicInfoVisible' instead"
        id="discourse.plugin-connector.deprecated-arg.header-contents.topic"
        since="3.3.0.beta4-dev"
        dropFrom="3.4.0"
        silence="discourse.header-service-topic"
      )
    }}
  />
</template>;

export default ContentsSecondary;
