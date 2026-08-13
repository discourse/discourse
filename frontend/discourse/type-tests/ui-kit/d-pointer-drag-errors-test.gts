import dPointerDrag from "discourse/ui-kit/modifiers/d-pointer-drag";

const Test = <template>
  {{! @glint-expect-error - threshold is a pixel count, not a string }}
  <span {{dPointerDrag threshold="4"}}></span>
</template>;

export default Test;
