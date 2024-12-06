import DModal from "discourse/components/d-modal";
import Content from "./content";

const EmojiPickerModal = <template>
  <DModal class="emoji-picker-modal" @closeModal={{@closeModal}}>
    <:body>
      <Content
        @close={{@closeModal}}
        @didSelectEmoji={{@model.didSelectEmoji}}
        @context={{@model.context}}
      />
    </:body>
  </DModal>
</template>;

export default EmojiPickerModal;
