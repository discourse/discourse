import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import TopicListItemExample from "../../examples/molecules/topic-list-item";
import topicListItemSource from "../../examples/molecules/topic-list-item?source=file";

export default <template>
  <StyleguideExample @code={{topicListItemSource}} @title="<TopicListItem>">
    <table class="topic-list">
      <tbody>
        <TopicListItemExample
          @showPosters={{@showPosters}}
          @topic={{@dummy.topic}}
        />
      </tbody>
    </table>
  </StyleguideExample>
</template>
