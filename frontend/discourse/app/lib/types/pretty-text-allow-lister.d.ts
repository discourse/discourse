// TODO(typescript-pending): the pretty-text package ships no type declarations
// and is not mapped into this project's type graph, so this ambient declaration
// types what `discourse/lib/text` consumes as a stopgap. Remove it once
// pretty-text/allow-lister provides its own types.
declare module "pretty-text/allow-lister" {
  export default class AllowLister {
    constructor(options?: object | null);
  }
}
