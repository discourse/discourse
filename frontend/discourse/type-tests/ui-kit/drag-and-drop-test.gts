// Positive template invocations of the drag/gesture primitives, asserting each
// Signature resolves in template position. Keep this file free of Glint
// directives: a single `@glint-expect-error` anywhere makes Glint stop
// reporting every other error in the file, so a broken declaration would pass
// unnoticed. Negatives live in drag-and-drop-errors-test.gts.
import { array, hash } from "@ember/helper";
import DResizeHandles from "discourse/ui-kit/d-resize-handles";
import DResizeSeparator from "discourse/ui-kit/d-resize-separator";
import dDragAndDropAutoScroll from "discourse/ui-kit/modifiers/d-drag-and-drop-auto-scroll";
import dDragAndDropExternalTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-external-target";
import dDragAndDropMonitor from "discourse/ui-kit/modifiers/d-drag-and-drop-monitor";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget, {
  DropTargetEvent,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import dPointerDrag from "discourse/ui-kit/modifiers/d-pointer-drag";

declare const noop: () => void;
declare const size: number;
declare const measure: () => number;
declare const measureMaybe: () => number | null;
declare const box: HTMLElement;
declare const handle: HTMLElement;
declare const payload: object;
declare const acceptedTypes: string[];

declare function onGesture(event: PointerEvent): void;
declare function vetoGesture(event: PointerEvent): boolean;
declare function onDropTargetEvent(event: DropTargetEvent): void;
declare function alwaysAdopt(feedback: {
  element: HTMLElement;
  source: unknown;
}): boolean;

declare const columnHandles: {
  payload: number;
  class?: string;
  style?: string;
}[];
declare function onColumnResize(column: number): void;
declare function onCompassResize(
  direction: "n" | "ne" | "e" | "se" | "s" | "sw" | "w" | "nw"
): void;

const Positives = <template>
  {{! A gesture takes every callback, and onDragStart may veto by returning false }}
  <span
    {{dPointerDrag
      onDragStart=vetoGesture
      onDrag=onGesture
      onDragEnd=onGesture
      onDragCancel=onGesture
      draggingClass="--dragging"
      bodyClass="d-resizing-ew"
      threshold=4
      stopPropagation=true
      cancelCommits=true
      touchAction="pan-y"
    }}
  ></span>

  {{! A callback that ignores the event still satisfies the gesture }}
  <span {{dPointerDrag onDragStart=noop}}></span>

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

  {{! The external target speaks the kind vocabulary, not drag types }}
  <div {{dDragAndDropExternalTarget accepts="files" onDrop=noop}}></div>
  <div
    {{dDragAndDropExternalTarget
      accepts=(array "files" "urls")
      indicator=false
      onDragEnter=noop
      onDrop=noop
    }}
  ></div>

  {{! An element target can also adopt a drag the browser started from page
      content nothing registered, gated by a predicate rather than a kind }}
  <div
    {{dDragAndDropTarget
      adopts=(hash type="web-link" match=alwaysAdopt)
      onDrop=onDropTargetEvent
    }}
  ></div>

  {{! An external target is a slot rather than a destination once it takes a
      position, and speaks the same vocabulary the element target does }}
  <li {{dDragAndDropExternalTarget accepts="urls" axis="y" onDrop=noop}}></li>
  <li
    {{dDragAndDropExternalTarget accepts="urls" position="inside" onDrop=noop}}
  ></li>

  {{! A monitor is global, so any sentinel element carries it }}
  <div {{dDragAndDropMonitor types=acceptedTypes onDrag=noop}}></div>

  {{! Auto-scroll defaults to the host element, or takes the window }}
  <div {{dDragAndDropAutoScroll types="card" axis="vertical"}}></div>
  <span {{dDragAndDropAutoScroll target="window" types=acceptedTypes}}></span>

  {{! Scrolling for a drag from outside the window is a separate opt-in, and
      speaks the kind vocabulary rather than the drag types beside it }}
  <div
    {{dDragAndDropAutoScroll types="card" accepts=(array "urls" "files")}}
  ></div>

  {{! A separator takes numbers or measurement functions for its size }}
  <DResizeSeparator
    @axis="vertical"
    @side="end"
    @value={{size}}
    @min={{size}}
    @max={{size}}
    @label="Resize"
    @observe={{box}}
    @onResizeStart={{noop}}
    class="my-block__handle"
  />
  <DResizeSeparator
    @axis="horizontal"
    @value={{measure}}
    @min={{measure}}
    @max={{measure}}
    @label="Resize"
  >grip</DResizeSeparator>
  {{! A measurement may honestly say "not yet": null withholds aria-valuenow }}
  <DResizeSeparator
    @axis="horizontal"
    @value={{measureMaybe}}
    @min={{size}}
    @max={{measureMaybe}}
    @label="Resize"
  />

  {{! The built-in box hands a compass direction to the handler }}
  <DResizeHandles @handleClass="my-block__handle" @threshold={{4}} />
  <DResizeHandles
    @handleClass="my-block__handle"
    @onResize={{onCompassResize}}
  />
  <DResizeHandles
    @handleClass="my-block__handle"
    @directions={{array "n" "s"}}
    @stopPropagation={{true}}
  />

  {{! Explicit descriptors carry the payload type through to the callbacks }}
  <DResizeHandles @handles={{columnHandles}} @onResize={{onColumnResize}} />
</template>;

export default Positives;
