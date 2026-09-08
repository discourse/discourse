import TopicList from "discourse/components/topic-list/list";

export default <template>
  <TopicList @showPosters={{false}} @topics={{@topics}} />
</template>
