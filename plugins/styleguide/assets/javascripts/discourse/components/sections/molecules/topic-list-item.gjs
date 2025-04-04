import LatestTopicListItem from "discourse/components/topic-list/latest-topic-list-item";
import TopicListItem from "discourse/components/topic-list-item";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const TopicListItem0 = <template>
  <StyleguideExample @title="<TopicListItem>">
    <table class="topic-list">
      <tbody>
        <TopicListItem @topic={{@dummy.topic}} @showPosters={{true}} />
      </tbody>
    </table>
  </StyleguideExample>

  <StyleguideExample @title="<TopicListItem> - hide category">
    <table class="topic-list">
      <tbody>
        <TopicListItem
          @topic={{@dummy.topic}}
          @hideCategory={{true}}
          @showPosters={{true}}
        />
      </tbody>
    </table>
  </StyleguideExample>

  <StyleguideExample @title="<TopicListItem> - show likes">
    <table class="topic-list">
      <tbody>
        <TopicListItem
          @topic={{@dummy.topic}}
          @showLikes={{true}}
          @showPosters={{true}}
        />
      </tbody>
    </table>
  </StyleguideExample>

  <StyleguideExample @title="<TopicListItem> - latest" class="half-size">
    {{#if this.site.useGlimmerTopicList}}
      <LatestTopicListItem @topic={{@dummy.topic}} />
    {{else}}
      <LatestTopicListItem @topic={{@dummy.topic}} />
    {{/if}}
  </StyleguideExample>
</template>;
export default TopicListItem0;
