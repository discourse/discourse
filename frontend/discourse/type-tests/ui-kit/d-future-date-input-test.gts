// Positive type assertions for DFutureDateInput: every invocation below must compile.
// Keep this file free of Glint error directives, because one would suppress reporting
// for the rest of the file. Negatives live in d-future-date-input-errors-test.gts.
import DFutureDateInput, {
  type DFutureDateInputShortcut,
} from "discourse/ui-kit/d-future-date-input";

declare const input: string | null;
declare const shortcuts: DFutureDateInputShortcut[];
declare function onChangeInput(value: string | null): void;

const Positives = <template>
  {{! Every arg is optional }}
  <DFutureDateInput />

  {{! The call sites in core }}
  <DFutureDateInput
    class="suspend-until"
    @clearable={{false}}
    @input={{input}}
    @label="admin.user.suspend_duration"
    @onChangeInput={{onChangeInput}}
  />
  <DFutureDateInput
    @clearable={{true}}
    @input={{input}}
    @noRelativeOptions={{true}}
    @onChangeInput={{onChangeInput}}
  />
  <DFutureDateInput
    @customShortcuts={{shortcuts}}
    @displayLabelIcon="far-clock"
    @includeDateTime={{false}}
    @includeNow={{true}}
    @labelClasses="slow-mode-label"
  />
</template>;

export default Positives;
