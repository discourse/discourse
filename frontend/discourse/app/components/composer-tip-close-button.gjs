import DButton from "discourse/ui-kit/d-button";

const ComposerTipCloseButton = <template>
  <DButton
    class="close"
    @action={{@action}}
    @ariaLabel="composer.esc_label"
    @icon="xmark"
    @label="composer.esc"
  />
</template>;

export default ComposerTipCloseButton;
