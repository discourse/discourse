import PinnedButton from "discourse/components/pinned-button";

export default <template>
  <PinnedButton @pinned={{true}} @topic={{@topic}} />
</template>
