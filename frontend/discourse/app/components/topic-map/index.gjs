import PluginOutlet from "discourse/components/plugin-outlet";
import PrivateMessageMap from "discourse/components/topic-map/private-message-map";
import TopicMapSummary from "discourse/components/topic-map/topic-map-summary";
import lazyHash from "discourse/helpers/lazy-hash";

const TopicMap = <template>
  {{#unless @model.postStream.loadingFilter}}
    <PluginOutlet
      @name="topic-map"
      @outletArgs={{lazyHash topic=@model postStream=@postStream}}
    >
      <section class="topic-map__contents">
        <TopicMapSummary
          @postStream={{@postStream}}
          @topic={{@model}}
          @topicDetails={{@topicDetails}}
        />
      </section>

      <PluginOutlet
        @defaultGlimmer={{true}}
        @name="topic-map-expanded-after"
        @outletArgs={{lazyHash topic=@model postStream=@postStream}}
      />

      {{#if @showPMMap}}
        <section class="topic-map__private-message-map">
          <PrivateMessageMap
            @removeAllowedGroup={{@removeAllowedGroup}}
            @removeAllowedUser={{@removeAllowedUser}}
            @showInvite={{@showInvite}}
            @topicDetails={{@topicDetails}}
          />
        </section>
      {{/if}}
    </PluginOutlet>
  {{/unless}}
</template>;

export default TopicMap;
