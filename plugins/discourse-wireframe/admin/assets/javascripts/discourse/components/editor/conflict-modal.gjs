// @ts-check
import { fn, hash } from "@ember/helper";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

/**
 * Shown when publishing an outlet is rejected because someone else published a
 * change to the same area while this session was editing (a stale-version 409).
 * The edit is preserved either way: overwrite republishes against the server's
 * current version (intentionally winning), and cancel (or dismiss) keeps the
 * outlet edited so the author can reconcile by hand.
 *
 * Closes with `{ choice: "overwrite" }`, or with nothing on cancel/dismiss; the
 * editor reads that result from the `modal.show` promise.
 */
const ConflictModal = <template>
  <DModal
    @title={{i18n "wireframe.conflict.title"}}
    @closeModal={{@closeModal}}
    class="wireframe-conflict"
  >
    <:body>
      <p>{{i18n "wireframe.conflict.description"}}</p>
    </:body>
    <:footer>
      <DButton
        class="btn-danger"
        @label="wireframe.conflict.overwrite"
        @action={{fn @closeModal (hash choice="overwrite")}}
      />
      <DButton
        class="btn-default"
        @label="wireframe.conflict.cancel"
        @action={{@closeModal}}
      />
    </:footer>
  </DModal>
</template>;

export default ConflictModal;
