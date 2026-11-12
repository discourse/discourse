import TopicList from "discourse/components/topic-list/list";

export default <template>
  <TopicList @showPosters={{true}} @topics={{@topics}} />
</template>
