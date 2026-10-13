// Negative type assertions for DButton's `@action` typing: every invocation below
// must fail to compile. They are quarantined here because a Glint error directive
// suppresses reporting elsewhere in its file, which would let a positive pass
// against a broken declaration. Positives live in d-button-action-test.gts.
//
// Each case stays on one line, hence the short names: the strict and non-strict
// projects report a multi-line invocation's error on different lines, and a
// directive only covers the line after it.
import DButton from "discourse/ui-kit/d-button";

interface Topic {
  id: number;
}

interface Draft {
  key: string;
}

declare const topic: Topic;
declare const flag: boolean;
declare function withEvent(topic: Topic, event: Event): void;
declare function readEvent(param: undefined, event: Event): void;
declare function save(draft: Draft): void;

// A handler that needs a parameter while `@actionParam` is omitted is also rejected,
// but only under `strictNullChecks`, where `undefined` stops fitting every type. This
// file is checked by the non-strict project as well, so that case is not asserted here.
const Negatives = <template>
  {{! @glint-expect-error - the handler wants a Draft but @actionParam is a Topic }}
  <DButton @action={{save}} @actionParam={{topic}} />

  {{! @glint-expect-error - the event only arrives with @forwardEvent }}
  <DButton @action={{withEvent}} @actionParam={{topic}} />

  {{! @glint-expect-error - an explicit false still withholds the event }}
  <DButton @action={{readEvent}} @forwardEvent={{false}} />

  {{! @glint-expect-error - a flag that may be false may withhold the event }}
  <DButton @action={{readEvent}} @forwardEvent={{flag}} />
</template>;

export default Negatives;
