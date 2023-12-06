import DButton from "discourse/components/d-button";

const CloseButton = <template>
  <DButton
    @icon="times"
    @action={{@close}}
    @title="chat.close"
    class="btn-flat btn-link chat-drawer-header__close-btn"
  />
</template>;

export default CloseButton;
