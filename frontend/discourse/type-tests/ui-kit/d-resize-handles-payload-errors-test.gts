/** Verifies that explicit handle descriptors determine the callback payload. Keep ONE error source inside each guarded element: a
 * directive suppresses every error in the element it guards, so a second
 * mistake added alongside this one would be absorbed silently.
 */
import DResizeHandles from "discourse/ui-kit/d-resize-handles";

declare const columnHandles: { payload: number }[];
declare function onDirectionResize(direction: string): void;

const Negative = <template>
  {{! @glint-expect-error - the descriptors pin the payload type, so a handler taking something else is rejected }}
  <DResizeHandles @handles={{columnHandles}} @onResize={{onDirectionResize}} />
</template>;

export default Negative;
