// Negative type assertions for the arguments a toast component receives: every
// invocation below must fail to compile. They are quarantined here because a
// Glint error directive suppresses reporting elsewhere in its file. Positives
// live in toast-component-args-test.gts.
import DDefaultToast from "discourse/float-kit/components/d-default-toast";

declare const shown: boolean;

const Negatives = <template>
  {{! @glint-expect-error - a progress bar needs its registration callback }}
  <DDefaultToast @showProgressBar={{true}} />

  {{! @glint-expect-error - a flag that may be true needs the callback too }}
  <DDefaultToast @showProgressBar={{shown}} />
</template>;

export default Negatives;
