// Keep this file free of @glint-expect-error directives so broken positive
// invocations cannot be masked by a negative assertion.
import dPointerDrag from "discourse/ui-kit/modifiers/d-pointer-drag";

declare const noop: () => void;
declare function onGesture(event: PointerEvent): void;
declare function vetoGesture(event: PointerEvent): boolean;

const Test = <template>
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

  <span {{dPointerDrag onDragStart=noop}}></span>
</template>;

export default Test;
