/** Verifies that unknown component arguments are rejected. */
import DResizeHandles from "discourse/ui-kit/d-resize-handles";

declare const noop: () => void;

const Negative = <template>
  {{! @glint-expect-error - an unknown arg is not silently ignored }}
  <DResizeHandles @handleClass="my-block__handle" @onResizeFinished={{noop}} />
</template>;

export default Negative;
