// Negative type assertions for external targets and auto-scroll: every
// invocation below MUST fail to compile. They are quarantined here because a
// `@glint-expect-error` suppresses reporting elsewhere in its file, which would
// let a positive assertion pass against a broken declaration. Positives live in
// d-drag-and-drop-external-test.gts.
import dDragAndDropAutoScroll from "discourse/ui-kit/modifiers/d-drag-and-drop-auto-scroll";
import dDragAndDropExternalTarget, {
  ExternalDropTargetEvent,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-external-target";
import dDragAndDropTarget, {
  DropTargetEvent,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-target";

declare function onExternalDrop(event: ExternalDropTargetEvent): void;
declare function onElementDrop(event: DropTargetEvent): void;

const Negatives = <template>
  {{! @glint-expect-error - the external vocabulary is a closed set of kinds, unlike the free-form drag types the element target filters on }}
  <div {{dDragAndDropExternalTarget accepts="images"}}></div>

  {{! @glint-expect-error - both targets resolve position the same way, so the external one rejects the same axes }}
  <div {{dDragAndDropExternalTarget accepts="urls" axis="x"}}></div>

  {{! @glint-expect-error - auto-scroll adds only "all" to the shared axis vocabulary }}
  <div {{dDragAndDropAutoScroll types="card" axis="both"}}></div>

  {{! @glint-expect-error - auto-scroll moves the host element or the window }}
  <div {{dDragAndDropAutoScroll target="document"}}></div>

  {{! @glint-expect-error - auto-scroll filters external drags by the same closed set of kinds the external target does }}
  <div {{dDragAndDropAutoScroll accepts="images"}}></div>

  {{! @glint-expect-error - the element and external targets report different payloads }}
  <li {{dDragAndDropTarget accepts="link" onDrop=onExternalDrop}}></li>

  {{! @glint-expect-error - and in the other direction: an element handler cannot read the external payload }}
  <li {{dDragAndDropExternalTarget accepts="files" onDrop=onElementDrop}}></li>
</template>;

export default Negatives;
