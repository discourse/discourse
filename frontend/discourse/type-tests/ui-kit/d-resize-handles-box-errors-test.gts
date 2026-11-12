/** Verifies that built-in handles always report compass directions. Keep ONE error source inside each guarded element: a
 * directive suppresses every error in the element it guards, so a second
 * mistake added alongside this one would be absorbed silently.
 */
import DResizeHandles from "discourse/ui-kit/d-resize-handles";

declare function onColumnResize(column: number): void;

const Negative = <template>
  {{! @glint-expect-error - the built-in box hands back compass directions, and the handler must not be allowed to decide the payload type for it }}
  <DResizeHandles @handleClass="handle" @onResize={{onColumnResize}} />
</template>;

export default Negative;
