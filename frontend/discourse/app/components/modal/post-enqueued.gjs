import { trustHTML } from "@ember/template";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const PostEnqueued = <template>
  <DModal
    @closeModal={{@closeModal}}
    @title={{i18n "review.approval.title"}}
    class="post-enqueued-modal"
  >
    <:body>
      <p>{{i18n "review.approval.description"}}</p>
      <p>
        {{trustHTML
          (i18n "review.approval.pending_posts" count=@model.pending_count)
        }}
      </p>
    </:body>
    <:footer>
      <DButton
        @action={{@closeModal}}
        class="btn-primary"
        @label="review.approval.ok"
      />
    </:footer>
  </DModal>
</template>;

export default PostEnqueued;
