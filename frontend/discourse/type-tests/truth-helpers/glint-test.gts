import type { TOC } from "@ember/component/template-only";
import { and, gt, or } from "discourse/truth-helpers";

interface ExpectStringSignature {
  Args: { value: string };
}

const ExpectString: TOC<ExpectStringSignature> = <template>
  <div>{{@value}}</div>
</template>;

interface HostSignature {
  Args: { maybeString?: string };
}

// Asserts the helpers keep their precise return types when invoked as template
// helpers (not just as direct function calls). Passing each result into a
// string-typed arg is the assertion; a wrong return type fails pnpm lint:types.
const Glint: TOC<HostSignature> = <template>
  {{! or of a maybe-string and a literal fallback resolves to a string }}
  <ExpectString @value={{or @maybeString "fallback"}} />

  {{! and of two string literals resolves to a string }}
  <ExpectString @value={{and "a" "b"}} />

  {{! @glint-expect-error - gt returns a boolean, not a string }}
  <ExpectString @value={{gt 1 2}} />
</template>;

export default Glint;
