// Keep this file free of @glint-expect-error directives so broken positive
// invocations cannot be masked by a negative assertion.
import { array } from "@ember/helper";
import { expectTypeOf } from "expect-type";
import type { ExternalDragPayload } from "discourse/lib/-internals/drag-and-drop/external-vocabulary";
import type { NormalizedDragSource } from "discourse/lib/-internals/drag-and-drop/vocabulary";
import dDragDwell, {
  type DragDwellEndEvent,
  type DragDwellEvent,
  type DragDwellFeedback,
  type DragDwellSource,
} from "discourse/ui-kit/modifiers/d-drag-dwell";

declare function open(event: DragDwellEvent): void;
declare function close(event: DragDwellEndEvent): void;
declare function gate(feedback: DragDwellFeedback): boolean;

/* The end event refines the dwell event: same payload plus the outcome. */
expectTypeOf<DragDwellEndEvent>().toExtend<DragDwellEvent>();
expectTypeOf<DragDwellEndEvent["reason"]>().toEqualTypeOf<
  "left" | "drag-ended"
>();

/* The exported source alias is exactly what every event's `source` can be. */
expectTypeOf<DragDwellEvent["source"]>().toEqualTypeOf<DragDwellSource>();

/* `family` discriminates: checking it narrows `source` to that family's
   payload, on the event, the feedback, and the end event alike. */
declare const event: DragDwellEvent;
if (event.family === "external") {
  expectTypeOf(event.source).toEqualTypeOf<ExternalDragPayload>();
} else {
  expectTypeOf(event.source).toEqualTypeOf<NormalizedDragSource>();
}

declare const feedback: DragDwellFeedback;
if (feedback.family === "element") {
  expectTypeOf(feedback.source).toEqualTypeOf<NormalizedDragSource>();
}

declare const end: DragDwellEndEvent;
if (end.family === "external") {
  expectTypeOf(end.source).toEqualTypeOf<ExternalDragPayload>();
}

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
