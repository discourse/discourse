// Positive template invocations for external targets and auto-scroll, asserting
// each Signature resolves in template position. Keep this file free of Glint
// directives: a single `@glint-expect-error` anywhere makes Glint stop reporting
// every other error in the file, so a broken declaration would pass unnoticed.
// Negatives live in d-drag-and-drop-external-errors-test.gts.
import { array } from "@ember/helper";
import dDragAndDropAutoScroll from "discourse/ui-kit/modifiers/d-drag-and-drop-auto-scroll";
import dDragAndDropExternalTarget, {
  ExternalDropTargetEvent,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-external-target";

declare const noop: () => void;
declare const acceptedTypes: string[];
declare function onExternalDrop(event: ExternalDropTargetEvent): void;

const Positives = <template>
  {{! The external target speaks the kind vocabulary, not drag types }}
  <div
    {{dDragAndDropExternalTarget accepts="files" onDrop=onExternalDrop}}
  ></div>
  <div
    {{dDragAndDropExternalTarget
      accepts=(array "files" "urls")
      indicator=false
      onDragEnter=noop
      onDrop=noop
    }}
  ></div>

  {{! An external target is a slot rather than a destination once it takes a
      position, and speaks the same vocabulary the element target does }}
  <li {{dDragAndDropExternalTarget accepts="urls" axis="y" onDrop=noop}}></li>
  <li
    {{dDragAndDropExternalTarget accepts="urls" position="inside" onDrop=noop}}
  ></li>

  {{! Auto-scroll defaults to the host element, or takes the window }}
  <div {{dDragAndDropAutoScroll types="card" axis="vertical"}}></div>
  <span {{dDragAndDropAutoScroll target="window" types=acceptedTypes}}></span>

  {{! Scrolling for a drag from outside the window is a separate opt-in, and
      speaks the kind vocabulary rather than the drag types beside it }}
  <div
    {{dDragAndDropAutoScroll types="card" accepts=(array "urls" "files")}}
  ></div>
</template>;

export default Positives;
