import TopicMap from "discourse/components/topic-map";

export default <template>
  <TopicMap @model={{@post}} @topicDetails={{@post.topic.details}} />
</template>
