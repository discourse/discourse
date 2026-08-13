/**
 * Positive template invocations for DResizeHandles. This file intentionally has
 * no Glint error directives, so a broken public signature cannot be suppressed.
 */
import { array } from "@ember/helper";
import DResizeHandles from "discourse/ui-kit/d-resize-handles";

declare const columnHandles: {
  payload: number;
  class?: string;
  style?: string;
}[];
declare function onColumnResize(column: number): void;
declare function onCompassResize(
  direction: "n" | "ne" | "e" | "se" | "s" | "sw" | "w" | "nw"
): void;

const Positives = <template>
  {{! The built-in box hands a compass direction to the handler }}
  <DResizeHandles @handleClass="my-block__handle" @threshold={{4}} />
  <DResizeHandles
    @handleClass="my-block__handle"
    @onResize={{onCompassResize}}
  />
  <DResizeHandles
    @handleClass="my-block__handle"
    @directions={{array "n" "s"}}
    @stopPropagation={{true}}
  />

  {{! Explicit descriptors carry the payload type through to the callbacks }}
  <DResizeHandles @handles={{columnHandles}} @onResize={{onColumnResize}} />
</template>;

export default Positives;
