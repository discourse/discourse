import DModal from "discourse/components/d-modal";
import htmlSafe from "discourse/helpers/html-safe";
import i18n from "discourse/helpers/i18n";
import DButton from "discourse/components/d-button";
const DeleteTopicDisallowed = <template><DModal @closeModal={{@closeModal}}>
  <:body>
    <p>{{htmlSafe (i18n "post.controls.delete_topic_disallowed_modal")}}</p>
  </:body>
  <:footer>
    <DButton @action={{@closeModal}} class="btn-primary" @label="close" />
  </:footer>
</DModal></template>;
export default DeleteTopicDisallowed;