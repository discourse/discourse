/** Your own handles decide the payload type the callbacks receive. Keep one mistake per guarded element. A
 * directive hides every error in the element it covers, so a second mistake
 * alongside this one would pass unnoticed.
 */
import DResizeHandles from "discourse/ui-kit/d-resize-handles";

declare const columnHandles: { payload: number }[];
declare function onDirectionResize(direction: string): void;

const Negative = <template>
  {{! @glint-expect-error - the descriptors pin the payload type, so a handler taking something else is rejected }}
  <DResizeHandles @handles={{columnHandles}} @onResize={{onDirectionResize}} />
</template>;

export default Negative;
