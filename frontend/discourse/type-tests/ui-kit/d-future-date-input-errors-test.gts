// Negative type assertions for DFutureDateInput: every invocation below must fail to
// compile. They are quarantined here because a Glint error directive suppresses
// reporting elsewhere in its file. Positives live in d-future-date-input-test.gts.
import DFutureDateInput from "discourse/ui-kit/d-future-date-input";

declare function onChangeNumber(value: number): void;

const Negatives = <template>
  {{! @glint-expect-error - onChangeInput is called with a string or null }}
  <DFutureDateInput @onChangeInput={{onChangeNumber}} />

  {{! @glint-expect-error - includeDateTime is a boolean }}
  <DFutureDateInput @includeDateTime="false" />

  {{! @glint-expect-error - there is no such arg }}
  <DFutureDateInput @selection="custom" />
</template>;

export default Negatives;
