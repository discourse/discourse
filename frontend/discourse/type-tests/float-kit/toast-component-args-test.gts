// Positive type assertions for the arguments a toast component receives: every
// invocation below must compile. Keep this file free of Glint error directives,
// because one would suppress reporting for the rest of the file. Negatives live
// in toast-component-args-errors-test.gts.
import DDefaultToast from "discourse/float-kit/components/d-default-toast";

declare function register(element: HTMLElement): void;
declare const shown: boolean;

const Positives = <template>
  {{! A progress bar comes with its registration callback }}
  <DDefaultToast
    @onRegisterProgressBar={{register}}
    @showProgressBar={{true}}
  />

  {{! Without a progress bar the callback is optional }}
  <DDefaultToast />
  <DDefaultToast @showProgressBar={{false}} />
  <DDefaultToast @onRegisterProgressBar={{register}} />

  {{! A computed flag is fine as long as the callback is there }}
  <DDefaultToast
    @onRegisterProgressBar={{register}}
    @showProgressBar={{shown}}
  />
</template>;

export default Positives;
