import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { fn, hash } from "@ember/helper";
import { type ComponentLike } from "@glint/template";
import DButton from "discourse/ui-kit/d-button";
import DModalUntyped from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

// TODO(devxp-typescript-pending): drop this cast once d-modal is authored in
// .gts with a real Signature, then import it directly. As an untyped .gjs it
// exposes no arg/block/attr types today, so its invocation is typed here at the
// boundary: the title and close-callback args, the body/footer blocks, and the
// root element that carries the `class`.
const DModal = DModalUntyped as unknown as ComponentLike<{
  /** Modal title and close callback. */
  Args: {
    /** Pre-translated modal title. */
    title?: string;
    /** Closes the modal and optionally resolves it with a result. */
    closeModal?: (
      /** Optional modal result. */
      result?: unknown
    ) => void;
  };
  /** Root modal element. */
  Element: HTMLDivElement;
  /** Blocks yielded by the modal. */
  Blocks: {
    /** Modal body content. */
    body: [];
    /** Modal footer actions. */
    footer: [];
  };
}>;

interface ConflictModalSignature {
  /** Modal lifecycle callback. */
  Args: {
    /** Closes the modal and optionally resolves it with the chosen action. */
    closeModal: (
      /** Optional modal result. */
      result?: unknown
    ) => void;
  };
}

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
const ConflictModal: TemplateOnlyComponent<ConflictModalSignature> = <template>
  <DModal
    class="wireframe-conflict"
    @closeModal={{@closeModal}}
    @title={{i18n "wireframe.conflict.title"}}
  >
    <:body>
      <p>{{i18n "wireframe.conflict.description"}}</p>
    </:body>
    <:footer>
      <DButton
        class="btn-danger"
        @action={{fn @closeModal (hash choice="overwrite")}}
        @label="wireframe.conflict.overwrite"
      />
      <DButton
        class="btn-default"
        @action={{@closeModal}}
        @label="wireframe.conflict.cancel"
      />
    </:footer>
  </DModal>
</template>;

export default ConflictModal;
