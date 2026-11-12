// Every invocation below MUST fail to compile. Negatives are quarantined here
// so a `@glint-expect-error` cannot mask a broken positive declaration.
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
  {{! @glint-expect-error - the external vocabulary is a closed set of kinds }}
  <div {{dDragAndDropExternalTarget accepts="images"}}></div>

  {{! @glint-expect-error - the external target rejects the same axes }}
  <div {{dDragAndDropExternalTarget accepts="urls" axis="x"}}></div>

  {{! @glint-expect-error - auto-scroll adds only "all" to the shared axis vocabulary }}
  <div {{dDragAndDropAutoScroll types="card" axis="both"}}></div>

  {{! @glint-expect-error - auto-scroll moves the host element or the window }}
  <div {{dDragAndDropAutoScroll target="document"}}></div>

  {{! @glint-expect-error - auto-scroll filters external drags by kind }}
  <div {{dDragAndDropAutoScroll externalKinds="images"}}></div>

  {{! @glint-expect-error - the element and external targets report different payloads }}
  <li {{dDragAndDropTarget accepts="link" onDrop=onExternalDrop}}></li>

  {{! @glint-expect-error - an element handler cannot read the external payload }}
  <li {{dDragAndDropExternalTarget accepts="files" onDrop=onElementDrop}}></li>
</template>;

export default Negatives;
