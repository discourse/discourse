// TODO(typescript-pending): the pretty-text package ships no type declarations
// and is not mapped into this project's type graph, so this ambient declaration
// types what `discourse/lib/text` consumes as a stopgap. Remove it once
// pretty-text/sanitizer provides its own types.
declare module "pretty-text/sanitizer" {
  import type AllowLister from "pretty-text/allow-lister";

  export function sanitize(
    text: string | null | undefined,
    allowLister: AllowLister
  ): string;
}
