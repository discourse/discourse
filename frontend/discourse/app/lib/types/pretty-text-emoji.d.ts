// TODO(typescript-pending): the pretty-text package ships no type declarations
// and is not mapped into this project's type graph, so this ambient declaration
// types what `discourse/lib/text` consumes as a stopgap. Remove it once
// pretty-text/emoji provides its own types.
declare module "pretty-text/emoji" {
  export function performEmojiUnescape(
    string: string | null | undefined,
    opts: object
  ): string | undefined;

  export function buildEmojiUrl(code: string, opts: object): string | undefined;

  export function buildAnimatedEmojiUrl(
    code: string,
    opts: object
  ): string | undefined;
}
