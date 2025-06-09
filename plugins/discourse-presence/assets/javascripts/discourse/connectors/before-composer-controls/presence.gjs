import ComposerPresenceDisplay from "discourse/plugins/discourse-presence/discourse/components/composer-presence-display";

const Presence = <template>
  <div class="before-composer-controls-outlet presence">
    <ComposerPresenceDisplay @model={{@outletArgs.model}} />
  </div>
</template>;

export default Presence;
