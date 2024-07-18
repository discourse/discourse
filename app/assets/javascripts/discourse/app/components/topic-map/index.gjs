import { hash } from "@ember/helper";
import PluginOutlet from "discourse/components/plugin-outlet";
import PrivateMessageMap from "discourse/components/topic-map/private-message-map";
import TopicMapSummary from "discourse/components/topic-map/topic-map-summary";

const TopicMap = <template>
  {{#unless @model.postStream.loadingFilter}}
    <section class="map">
      <TopicMapSummary
        @topic={{@model}}
        @topicDetails={{@topicDetails}}
        @postStream={{@postStream}}
      />
    </section>
  {{/unless}}

  <section class="information toggle-summary">
    <PluginOutlet
      @name="topic-map-expanded-after"
      @defaultGlimmer={{true}}
      @outletArgs={{hash topic=@model postStream=@postStream}}
    />
  </section>

  {{#if @showPMMap}}
    <section class="information private-message-map">
      <PrivateMessageMap
        @topicDetails={{@topicDetails}}
        @showInvite={{@showInvite}}
        @removeAllowedGroup={{@removeAllowedGroup}}
        @removeAllowedUser={{@removeAllowedUser}}
      />
    </section>
  {{/if}}
</template>;

export default TopicMap;
