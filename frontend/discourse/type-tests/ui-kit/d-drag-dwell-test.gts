// Keep this file free of @glint-expect-error directives so broken positive
// invocations cannot be masked by a negative assertion.
import { array } from "@ember/helper";
import { expectTypeOf } from "expect-type";
import dDragDwell, {
  type DragDwellEndEvent,
  type DragDwellEvent,
  type DragDwellFeedback,
} from "discourse/ui-kit/modifiers/d-drag-dwell";

declare function open(event: DragDwellEvent): void;
declare function close(event: DragDwellEndEvent): void;
declare function gate(feedback: DragDwellFeedback): boolean;

/* The end event refines the dwell event: same payload plus the outcome. */
expectTypeOf<DragDwellEndEvent>().toMatchTypeOf<DragDwellEvent>();
expectTypeOf<DragDwellEndEvent["reason"]>().toEqualTypeOf<
  "left" | "drag-ended"
>();

const Positives = <template>
  {{! Minimal: one drag family and the dwell callback. }}
  <div {{dDragDwell types="card" onDwell=open}}></div>

  {{! Maximal: every named arg. }}
  <div
    {{dDragDwell
      types="card"
      externalKinds="text"
      delay=700
      canDwell=gate
      acceptsSelf=false
      onDwell=open
      onDwellEnd=close
    }}
  ></div>

  {{! Arrays for both filters. }}
  <div
    {{dDragDwell
      types=(array "card" "row")
      externalKinds=(array "text" "urls")
      onDwell=open
    }}
  ></div>
</template>;

export default Positives;
