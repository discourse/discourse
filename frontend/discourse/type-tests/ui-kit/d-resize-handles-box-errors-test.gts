/** The box handles always report compass directions. Keep one mistake per guarded element. A
 * directive hides every error in the element it covers, so a second mistake
 * alongside this one would pass unnoticed.
 */
import DResizeHandles from "discourse/ui-kit/d-resize-handles";

declare function onColumnResize(column: number): void;

const Negative = <template>
  {{! @glint-expect-error - the built-in box hands back compass directions, and the handler must not be allowed to decide the payload type for it }}
  <DResizeHandles @handleClass="handle" @onResize={{onColumnResize}} />
</template>;

export default Negative;
