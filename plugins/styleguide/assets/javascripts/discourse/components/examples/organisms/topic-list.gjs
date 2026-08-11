import TopicList from "discourse/components/topic-list/list";

export default <template>
  <TopicList @topics={{@topics}} @showPosters={{true}} />
</template>
