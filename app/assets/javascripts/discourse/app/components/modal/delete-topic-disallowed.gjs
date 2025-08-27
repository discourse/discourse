import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

const DeleteTopicDisallowed = <template>
  <DModal @closeModal={{@closeModal}}>
    <:body>
      <p>{{htmlSafe (i18n "post.controls.delete_topic_disallowed_modal")}}</p>
    </:body>
    <:footer>
      <DButton @action={{@closeModal}} class="btn-primary" @label="close" />
    </:footer>
  </DModal>
</template>;

export default DeleteTopicDisallowed;
