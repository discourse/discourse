/** Verifies that unknown component arguments are rejected. Keep ONE error source inside each guarded element: a
 * directive suppresses every error in the element it guards, so a second
 * mistake added alongside this one would be absorbed silently.
 */
import DResizeHandles from "discourse/ui-kit/d-resize-handles";

declare const noop: () => void;

const Negative = <template>
  {{! @glint-expect-error - an unknown arg is not silently ignored }}
  <DResizeHandles @handleClass="my-block__handle" @onResizeFinished={{noop}} />
</template>;

export default Negative;
