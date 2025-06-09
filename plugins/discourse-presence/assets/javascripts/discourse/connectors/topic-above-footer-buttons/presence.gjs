import TopicPresenceDisplay from "discourse/plugins/discourse-presence/discourse/components/topic-presence-display";

const Presence = <template>
  <div class="topic-above-footer-buttons-outlet presence">
    <TopicPresenceDisplay @topic={{@outletArgs.model}} />
  </div>
</template>;

export default Presence;
