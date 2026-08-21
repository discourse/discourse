// Every invocation below MUST fail to compile. Negatives are quarantined
// here so a @glint-expect-error cannot mask a broken positive declaration.
import dDragDwell, {
  type DragDwellEvent,
} from "discourse/ui-kit/modifiers/d-drag-dwell";

declare function open(event: DragDwellEvent): void;

const Negatives = <template>
  {{! @glint-expect-error - onDwell is required }}
  <div {{dDragDwell types="card"}}></div>

  {{! @glint-expect-error - delay is a number of milliseconds }}
  <div {{dDragDwell types="card" delay="500" onDwell=open}}></div>

  {{! @glint-expect-error - externalKinds is the closed external-kind vocabulary }}
  <div {{dDragDwell externalKinds="images" onDwell=open}}></div>

  {{! @glint-expect-error - unknown args are rejected }}
  <div {{dDragDwell types="card" eagerness="high" onDwell=open}}></div>

  {{! @glint-expect-error - position is drop-target vocabulary, not dwell }}
  <div {{dDragDwell types="card" position="inside" onDwell=open}}></div>
</template>;

export default Negatives;
