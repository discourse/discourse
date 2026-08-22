import dPointerDrag from "discourse/ui-kit/modifiers/d-pointer-drag";

declare function onGesture(event: PointerEvent): void;

const Test = <template>
  {{! @glint-expect-error - threshold is a pixel count, not a string }}
  <span {{dPointerDrag threshold="4"}}></span>

  {{! @glint-expect-error - touchAction is closed against the stylesheet, and "auto" has no rule }}
  <span {{dPointerDrag touchAction="auto"}}></span>

  {{! @glint-expect-error - a typo'd token would silently leave touch-action at auto }}
  <span {{dPointerDrag touchAction="pan-Y"}}></span>

  {{! @glint-expect-error - stopPropagation is a flag, not a string }}
  <span {{dPointerDrag stopPropagation="true"}}></span>

  {{! @glint-expect-error - preventDefault is a flag, not a string }}
  <span {{dPointerDrag preventDefault="false"}}></span>

  {{! @glint-expect-error - capturePressTarget is a flag, not a string }}
  <span {{dPointerDrag capturePressTarget="true"}}></span>

  {{! @glint-expect-error - onDrag receives the event; it cannot take extra arguments }}
  <span {{dPointerDrag onDrag=onGesture extra=1}}></span>

  {{! @glint-expect-error - the gesture takes no positional arguments }}
  <span {{dPointerDrag onGesture}}></span>
</template>;

export default Test;
