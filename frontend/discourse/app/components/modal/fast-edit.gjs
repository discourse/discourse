import FastEdit from "discourse/components/fast-edit";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const FastEditModal = <template>
  <DModal @closeModal={{@closeModal}} @title={{i18n "post.quote_edit"}}>
    <FastEdit
      @close={{@closeModal}}
      @initialValue={{@model.initialValue}}
      @newValue={{@model.newValue}}
      @post={{@model.post}}
    />
  </DModal>
</template>;

export default FastEditModal;
