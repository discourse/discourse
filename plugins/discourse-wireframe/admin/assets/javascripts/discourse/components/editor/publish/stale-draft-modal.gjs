// @ts-check
import { fn, hash } from "@ember/helper";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

/**
 * Shown on entry when a restored per-user draft was based on an older version
 * of the live layout than what is published now. The choice is whole-document:
 * keep the draft, or start fresh from the live layout. Dismissing (escape /
 * close) leaves the live layout in place and keeps the draft for next time, so
 * nothing is lost by accident.
 *
 * Closes with `{ choice: "keep" }` or `{ choice: "fresh" }`; the editor service
 * reads that result from the `modal.show` promise and acts on it.
 */
const StaleDraftModal = <template>
  <DModal
    @title={{i18n "wireframe.stale_draft.title"}}
    @closeModal={{@closeModal}}
    class="wireframe-stale-draft"
  >
    <:body>
      <p>{{i18n "wireframe.stale_draft.description"}}</p>
    </:body>
    <:footer>
      <DButton
        class="btn-primary"
        @label="wireframe.stale_draft.keep"
        @action={{fn @closeModal (hash choice="keep")}}
      />
      <DButton
        class="btn-default"
        @label="wireframe.stale_draft.start_fresh"
        @action={{fn @closeModal (hash choice="fresh")}}
      />
    </:footer>
  </DModal>
</template>;

export default StaleDraftModal;
