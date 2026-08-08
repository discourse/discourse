import TopicStatus from "discourse/components/topic-status";
import dTopicLink from "discourse/ui-kit/helpers/d-topic-link";

export default <template>
  <TopicStatus @topic={{@topic}} />
  {{dTopicLink @topic}}
</template>
