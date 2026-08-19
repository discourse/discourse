// Every invocation below MUST fail to compile. Negatives are quarantined here
// so a `@glint-expect-error` cannot mask a broken positive declaration.
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";

declare const payload: object;

const Negatives = <template>
  {{! @glint-expect-error - a selector is not an element; the handle ref must be }}
  <li {{dDragAndDropSource type="link" dragHandle="#handle"}}></li>

  {{! @glint-expect-error - the discriminator is required }}
  <li {{dDragAndDropSource data=payload}}></li>

  {{! @glint-expect-error - "moveCopy" is not a permitted effect }}
  <li {{dDragAndDropSource type="link" effectAllowed="moveCopy"}}></li>

  {{! @glint-expect-error - the axis vocabulary is vertical and horizontal }}
  <li {{dDragAndDropTarget accepts="link" axis="y"}}></li>

  {{! @glint-expect-error - a drop lands before, after or inside, nowhere else }}
  <li {{dDragAndDropTarget accepts="link" position="middle"}}></li>
</template>;

export default Negatives;
