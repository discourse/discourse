import DButton from "discourse/components/d-button";

const ComposerTipCloseButton = <template>
  <DButton
    @action={{@action}}
    @icon="xmark"
    @label="composer.esc"
    @ariaLabel="composer.esc_label"
    class="btn-transparent close"
  />
</template>;

export default ComposerTipCloseButton;
