import ComposerPresenceDisplay from "discourse/plugins/discourse-presence/discourse/components/composer-presence-display";

const Presence = <template>
  <ComposerPresenceDisplay @model={{@outletArgs.model}} />
</template>;
export default Presence;
