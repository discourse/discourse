// Negative type assertions for DButton's `@action` typing: every invocation below
// must fail to compile. They are quarantined here because a Glint error directive
// suppresses reporting elsewhere in its file, which would let a positive pass
// against a broken declaration. Positives live in d-button-action-test.gts.
//
// Each case stays on one line, hence the short names, so the directive above it
// covers the whole invocation.
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

const Negatives = <template>
  {{! @glint-expect-error - the handler wants a Draft but @actionParam is omitted }}
  <DButton @action={{save}} />

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
