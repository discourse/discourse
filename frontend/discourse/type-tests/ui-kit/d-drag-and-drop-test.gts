// Positive template invocations of the element drag-and-drop primitives,
// asserting each Signature resolves in template position. Keep this file free
// of Glint directives: a single `@glint-expect-error` anywhere makes Glint stop
// reporting every other error in the file, so a broken declaration would pass
// unnoticed. Negatives live in d-drag-and-drop-errors-test.gts.
import { hash } from "@ember/helper";
import dDragAndDropMonitor from "discourse/ui-kit/modifiers/d-drag-and-drop-monitor";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget, {
  DropTargetEvent,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-target";

declare const noop: () => void;
declare const handle: HTMLElement;
declare const payload: object;
declare const acceptedTypes: string[];

declare function onDropTargetEvent(event: DropTargetEvent): void;

const Positives = <template>
  {{! A source takes a single type, an arbitrary payload object, and a handle }}
  <li
    {{dDragAndDropSource
      type="sidebar-link"
      data=payload
      dragHandle=handle
      dragPreviewOffset=(hash x="1rem" y="0.5rem")
      effectAllowed="copyMove"
      disabled=false
      onDragStart=noop
      onDragEnd=noop
      onDrop=noop
    }}
  ></li>

  {{! A target accepts one type or several, and reports a normalised source }}
  <li
    {{dDragAndDropTarget accepts="sidebar-link" onDrop=onDropTargetEvent}}
  ></li>
  <li
    {{dDragAndDropTarget
      accepts=acceptedTypes
      acceptsSelf=false
      position="inside"
      axis="x"
      indicator=false
      onDragEnter=onDropTargetEvent
      onDrag=onDropTargetEvent
      onDragLeave=onDropTargetEvent
      onDrop=onDropTargetEvent
    }}
  ></li>

  {{! A monitor is global, so any sentinel element carries it }}
  <div {{dDragAndDropMonitor types=acceptedTypes onDrag=noop}}></div>
</template>;

export default Positives;
