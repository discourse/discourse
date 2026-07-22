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

interface StaleDraftModalSignature {
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
 * Shown on entry when a restored per-user draft was based on an older version
 * of the live layout than what is published now. The choice is whole-document:
 * keep the draft, or start fresh from the live layout. Dismissing (escape /
 * close) leaves the live layout in place and keeps the draft for next time, so
 * nothing is lost by accident.
 *
 * Closes with `{ choice: "keep" }` or `{ choice: "fresh" }`; the editor service
 * reads that result from the `modal.show` promise and acts on it.
 */
const StaleDraftModal: TemplateOnlyComponent<StaleDraftModalSignature> =
  <template>
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
