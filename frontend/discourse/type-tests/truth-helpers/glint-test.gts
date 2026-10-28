import type { TOC } from "@ember/component/template-only";

interface ExpectStringSignature {
  Args: { value: string };
}

const ExpectString: TOC<ExpectStringSignature> = <template>
  <div>{{@value}}</div>
</template>;

interface ExpectFooBarSignature {
  Args: { value: "foo" | "bar" };
}

const ExpectFooBar: TOC<ExpectFooBarSignature> = <template>
  <div>{{@value}}</div>
</template>;

interface HostSignature {
  Args: { maybeString?: string; fooBar: "foo" | "bar" };
}

// Asserts the built-in `or`/`and`/`gt` keywords keep their precise return types.
// Feeding each result into a narrowly-typed arg is the assertion; a wrong return
// type fails pnpm lint:types.
const Glint: TOC<HostSignature> = <template>
  {{! or of a maybe-string and a literal fallback resolves to a string }}
  <ExpectString @value={{or @maybeString "fallback"}} />

  {{! and of two string literals resolves to a string }}
  <ExpectString @value={{and "a" "b"}} />

  {{! a leading falsy value is skipped and the enum's literal type is preserved }}
  <ExpectFooBar @value={{or false @fooBar}} />

  {{! all-truthy and returns the last argument, preserving its literal type }}
  <ExpectFooBar @value={{and "x" @fooBar}} />

  {{! @glint-expect-error - gt returns a boolean, not a string }}
  <ExpectString @value={{gt 1 2}} />
</template>;

export default Glint;
