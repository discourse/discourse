// Negative type assertions for native drag adoption: every invocation below
// must fail. They are quarantined because an expected Glint error suppresses
// reporting elsewhere in its file.
import { hash } from "@ember/helper";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";

declare const noop: () => void;

const Negatives = <template>
  {{! @glint-expect-error - adoption requires a predicate, not an external kind }}
  <div {{dDragAndDropTarget adopts="urls"}}></div>

  {{! @glint-expect-error - an adoption needs a consumer-facing type }}
  <div {{dDragAndDropTarget adopts=(hash match=noop)}}></div>

  {{! @glint-expect-error - the adoption predicate must return a decision }}
  <div {{dDragAndDropTarget adopts=(hash type="web-link" match=noop)}}></div>
</template>;

export default Negatives;
