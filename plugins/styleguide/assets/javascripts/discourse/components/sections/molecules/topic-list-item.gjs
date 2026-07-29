import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import TopicListItemExample from "../../examples/molecules/topic-list-item";
import topicListItemSource from "../../examples/molecules/topic-list-item?source=file";

export default <template>
  <StyleguideExample @title="<TopicListItem>" @code={{topicListItemSource}}>
    <table class="topic-list">
      <tbody>
        <TopicListItemExample
          @topic={{@dummy.topic}}
          @showPosters={{@showPosters}}
        />
      </tbody>
    </table>
  </StyleguideExample>
</template>
