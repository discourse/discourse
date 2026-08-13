// Negative type assertions for the element drag-and-drop primitives: every
// invocation below MUST fail to compile. They are quarantined here because a
// `@glint-expect-error` suppresses reporting elsewhere in its file, which
// would let a positive assertion pass against a broken declaration. Positives
// live in d-drag-and-drop-test.gts.
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";

declare const payload: object;

const Negatives = <template>
  {{! @glint-expect-error - a selector is not an element; the handle ref must be }}
  <li {{dDragAndDropSource type="link" dragHandle="#handle"}}></li>

  {{! @glint-expect-error - the discriminator is required, since targets filter on it and the service identifies its own drags by it }}
  <li {{dDragAndDropSource data=payload}}></li>

  {{! @glint-expect-error - a drag permits a fixed set of operations, and move-copy is not one of their spellings }}
  <li {{dDragAndDropSource type="link" effectAllowed="moveCopy"}}></li>

  {{! @glint-expect-error - the axis vocabulary is x and y }}
  <li {{dDragAndDropTarget accepts="link" axis="z"}}></li>

  {{! @glint-expect-error - a drop lands before, after or inside, nowhere else }}
  <li {{dDragAndDropTarget accepts="link" position="middle"}}></li>
</template>;

export default Negatives;
