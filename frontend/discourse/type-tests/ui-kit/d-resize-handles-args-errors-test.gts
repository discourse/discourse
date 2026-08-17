/** Unknown component arguments must be rejected. Keep one mistake per guarded element. A
 * directive hides every error in the element it covers, so a second mistake
 * alongside this one would pass unnoticed.
 */
import DResizeHandles from "discourse/ui-kit/d-resize-handles";

declare const noop: () => void;

const Negative = <template>
  {{! @glint-expect-error - an unknown arg is not silently ignored }}
  <DResizeHandles @handleClass="my-block__handle" @onResizeFinished={{noop}} />
</template>;

export default Negative;
