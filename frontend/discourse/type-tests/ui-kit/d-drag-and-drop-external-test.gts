// Keep this file free of @glint-expect-error directives so broken positive
// invocations cannot be masked by a negative assertion.
import { array } from "@ember/helper";
import dDragAndDropAutoScroll from "discourse/ui-kit/modifiers/d-drag-and-drop-auto-scroll";
import dDragAndDropExternalTarget, {
  ExternalDropTargetEvent,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-external-target";

declare const noop: () => void;
declare const acceptedTypes: string[];
declare function onExternalDrop(event: ExternalDropTargetEvent): void;
declare function describeTarget(): { slot: string };
declare function isSticky(): boolean;

const Positives = <template>
  {{! The external target speaks the kind vocabulary, not drag types }}
  <div
    {{dDragAndDropExternalTarget accepts="files" onDrop=onExternalDrop}}
  ></div>

  {{! Target-side metadata and stickiness are shared with the element target }}
  <div
    {{dDragAndDropExternalTarget
      accepts="files"
      getData=describeTarget
      getIsSticky=isSticky
    }}
  ></div>
  <div
    {{dDragAndDropExternalTarget
      accepts=(array "files" "urls")
      indicator=false
      onDragEnter=noop
      onDrop=noop
    }}
  ></div>

  {{! A positioned external target shares the element target's vocabulary }}
  <li
    {{dDragAndDropExternalTarget accepts="urls" axis="vertical" onDrop=noop}}
  ></li>
  <li
    {{dDragAndDropExternalTarget accepts="urls" position="inside" onDrop=noop}}
  ></li>

  {{! Auto-scroll defaults to the host element, or takes the window }}
  <div {{dDragAndDropAutoScroll types="card" axis="vertical"}}></div>
  <span {{dDragAndDropAutoScroll target="window" types=acceptedTypes}}></span>

  {{! External auto-scroll is a separate opt-in keyed by kind, not drag type }}
  <div
    {{dDragAndDropAutoScroll types="card" accepts=(array "urls" "files")}}
  ></div>
</template>;

export default Positives;
