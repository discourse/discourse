import DModal from "discourse/components/d-modal";
import i18n from "discourse/helpers/i18n";
import FastEdit from "discourse/components/fast-edit";
const FastEdit = <template><DModal @title={{i18n "post.quote_edit"}} @closeModal={{@closeModal}}>
  <FastEdit @newValue={{@model.newValue}} @initialValue={{@model.initialValue}} @post={{@model.post}} @close={{@closeModal}} />
</DModal></template>;
export default FastEdit;