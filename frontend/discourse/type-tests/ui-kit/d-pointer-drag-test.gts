// Keep this file free of @glint-expect-error directives so broken positive
// invocations cannot be masked by a negative assertion.
import dPointerDrag, {
  type DPointerDragArgs,
  registerPointerDrag,
  type TouchActionToken,
} from "discourse/ui-kit/modifiers/d-pointer-drag";

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
      preservePress=true
      cancelCommits=true
      touchAction="pan-y"
    }}
  ></span>

  <span {{dPointerDrag onDragStart=noop}}></span>
</template>;

/**
 * The imperative entry point is exported public API too, so it is checked here
 * rather than only through the modifier. Never invoked.
 */
export function checkImperativeSurface(handle: HTMLElement) {
  const touchAction: TouchActionToken = "manipulation";
  const args: DPointerDragArgs = {
    onDragStart: vetoGesture,
    onDrag: onGesture,
    threshold: 4,
    touchAction,
  };

  const cleanup: () => void = registerPointerDrag(handle, () => args);
  cleanup();
}

export default Test;
