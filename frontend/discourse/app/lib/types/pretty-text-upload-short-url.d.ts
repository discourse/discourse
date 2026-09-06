// TODO(devxp-typescript-pending): the pretty-text package ships no type
// declarations and is not mapped into this project's type graph, so this
// ambient declaration types the one symbol consumed by the rich editor as a
// stopgap. A `declare module` for an otherwise-unresolvable module must live
// in a `.d.ts` (in a `.ts` module it becomes an augmentation and fails with
// TS2664). The proper fix is to wire pretty-text into the type-checking
// pipeline and convert the source module to TypeScript; remove this file once
// pretty-text/upload-short-url provides its own types.
declare module "pretty-text/upload-short-url" {
  interface CachedUploadUrl {
    url?: string;
    short_path?: string;
  }

  export function lookupCachedUploadUrl(shortUrl: string): CachedUploadUrl;
}
