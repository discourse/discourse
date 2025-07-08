import LatestTopicListItem from "discourse/components/topic-list/latest-topic-list-item";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const TopicListItem = <template>
  <StyleguideExample @title="<TopicListItem>">
    <table class="topic-list">
      <tbody>
        <LatestTopicListItem @topic={{@dummy.topic}} @showPosters={{true}} />
      </tbody>
    </table>
  </StyleguideExample>

  <StyleguideExample @title="<TopicListItem> - hide category">
    <table class="topic-list">
      <tbody>
        <LatestTopicListItem
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
        <LatestTopicListItem
          @topic={{@dummy.topic}}
          @showLikes={{true}}
          @showPosters={{true}}
        />
      </tbody>
    </table>
  </StyleguideExample>

  <StyleguideExample @title="<TopicListItem> - latest" class="half-size">
    <LatestTopicListItem @topic={{@dummy.topic}} />
  </StyleguideExample>
</template>;

export default TopicListItem;
