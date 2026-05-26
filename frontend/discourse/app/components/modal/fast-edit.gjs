import FastEdit from "discourse/components/fast-edit";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const FastEditModal = <template>
  <DModal @title={{i18n "post.quote_edit"}} @closeModal={{@closeModal}}>
    <FastEdit
      @newValue={{@model.newValue}}
      @initialValue={{@model.initialValue}}
      @post={{@model.post}}
      @close={{@closeModal}}
    />
  </DModal>
</template>;

export default FastEditModal;
