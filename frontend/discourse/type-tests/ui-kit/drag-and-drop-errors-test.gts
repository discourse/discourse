// Negative type assertions for the drag/gesture primitives: every invocation
// below MUST fail to compile. They are quarantined here because a
// `@glint-expect-error` suppresses reporting elsewhere in its file, which would
// let a positive assertion pass against a broken declaration. Positives live in
// drag-and-drop-test.gts.
import DResizeHandles from "discourse/ui-kit/d-resize-handles";
import DResizeSeparator from "discourse/ui-kit/d-resize-separator";
import dDragAndDropAutoScroll from "discourse/ui-kit/modifiers/d-drag-and-drop-auto-scroll";
import dDragAndDropExternalTarget, {
  ExternalDropTargetEvent,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-external-target";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import dPointerDrag from "discourse/ui-kit/modifiers/d-pointer-drag";

declare const noop: () => void;
declare const px: number;
declare const payload: object;

declare const columnHandles: { payload: number }[];
declare function onDirectionResize(direction: string): void;
declare function onColumnResize(column: number): void;
declare function onExternalDrop(event: ExternalDropTargetEvent): void;

const Negatives = <template>
  {{! @glint-expect-error - threshold is a pixel count, not a string }}
  <span {{dPointerDrag threshold="4"}}></span>

  {{! @glint-expect-error - a selector is not an element; the handle ref must be }}
  <li {{dDragAndDropSource type="link" dragHandle="#handle"}}></li>

  {{! @glint-expect-error - the discriminator is required, since targets filter on it and the service identifies its own drags by it }}
  <li {{dDragAndDropSource data=payload}}></li>

  {{! @glint-expect-error - the axis vocabulary is x and y }}
  <li {{dDragAndDropTarget accepts="link" axis="z"}}></li>

  {{! @glint-expect-error - a drop lands before, after or inside, nowhere else }}
  <li {{dDragAndDropTarget accepts="link" position="middle"}}></li>

  {{! @glint-expect-error - the external vocabulary is a closed set of kinds, unlike the free-form drag types the element target filters on }}
  <div {{dDragAndDropExternalTarget accepts="images"}}></div>

  {{! @glint-expect-error - auto-scroll moves the host element or the window }}
  <div {{dDragAndDropAutoScroll target="document"}}></div>

  {{! @glint-expect-error - the element and external targets report different payloads }}
  <li {{dDragAndDropTarget accepts="link" onDrop=onExternalDrop}}></li>

  {{! @glint-expect-error - a focusable separator with no accessible name is announced as a bare splitter, so the label is required }}
  <DResizeSeparator @value={{px}} @min={{px}} @max={{px}} />

  <DResizeSeparator
    {{! @glint-expect-error - a separator resizes along one of two axes }}
    @axis="diagonal"
    @value={{px}}
    @min={{px}}
    @max={{px}}
    @label="Resize"
  />

  {{! @glint-expect-error - the descriptors pin the payload type, so a handler taking something else is rejected }}
  <DResizeHandles @handles={{columnHandles}} @onResize={{onDirectionResize}} />

  {{! @glint-expect-error - the built-in box hands back compass directions, and the handler must not be allowed to decide the payload type for it }}
  <DResizeHandles @handleClass="handle" @onResize={{onColumnResize}} />

  {{! @glint-expect-error - an unknown arg is not silently ignored }}
  <DResizeHandles @handleClass="my-block__handle" @onResizeFinished={{noop}} />
</template>;

export default Negatives;
