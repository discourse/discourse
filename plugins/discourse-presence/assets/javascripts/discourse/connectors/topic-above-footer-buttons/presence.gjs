import TopicPresenceDisplay from "discourse/plugins/discourse-presence/discourse/components/topic-presence-display";

const Presence = <template>
  <TopicPresenceDisplay @topic={{@outletArgs.model}} />
</template>;
export default Presence;
