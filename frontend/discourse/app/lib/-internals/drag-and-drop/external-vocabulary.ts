import type {
  ExternalDragPayload as NativeExternalDragPayload,
  NativeMediaType,
} from "@atlaskit/pragmatic-drag-and-drop/adapter/external-adapter-types";
import { containsFiles } from "@atlaskit/pragmatic-drag-and-drop/utils/contains-files";
import { containsHTML } from "@atlaskit/pragmatic-drag-and-drop/utils/contains-html";
import { containsText } from "@atlaskit/pragmatic-drag-and-drop/utils/contains-text";
import { containsURLs } from "@atlaskit/pragmatic-drag-and-drop/utils/contains-ur-ls";
import { getFiles } from "@atlaskit/pragmatic-drag-and-drop/utils/get-files";
import { getHTML } from "@atlaskit/pragmatic-drag-and-drop/utils/get-html";
import { getText } from "@atlaskit/pragmatic-drag-and-drop/utils/get-text";
import { getURLs } from "@atlaskit/pragmatic-drag-and-drop/utils/get-ur-ls";
import { makeArray } from "discourse/lib/helpers";

/**
 * The in-flight external drag, with the read helpers bound to it so consumers
 * never reach for the underlying library themselves.
 */
export interface ExternalDragPayload {
  /**
   * Native MIME types declared by the incoming drag (e.g. `"Files"`,
   * `"text/plain"`, `"text/uri-list"`).
   */
  types: NativeMediaType[];

  /**
   * The `DataTransferItem` list. Empty until the drop, so `getFiles()` returns
   * files in `onDrop` alone. Use `types` or `containsFiles()` while hovering.
   */
  items: DataTransferItem[];

  /**
   * Reads the string payload for a MIME type. Returns `null` while hovering,
   * and at the drop when the type is absent.
   */
  getStringData: (mediaType: string) => string | null;

  containsFiles: () => boolean;
  getFiles: () => File[];
  containsHTML: () => boolean;
  getHTML: () => string | null;
  containsText: () => boolean;
  getText: () => string | null;
  containsURLs: () => boolean;
  getURLs: () => string[];
}

/**
 * The kinds `accepts` / `acceptsExternal()` understand, each mapped to its
 * payload predicate.
 */
const EXTERNAL_KIND_PREDICATES = Object.freeze({
  files: containsFiles,
  html: containsHTML,
  text: containsText,
  urls: containsURLs,
});

/** A kind of external payload, as named by `accepts` / `acceptsExternal()`. */
export type ExternalDragKind = keyof typeof EXTERNAL_KIND_PREDICATES;

/**
 * Binds the read helpers to the library's raw external payload.
 *
 * @param source - The raw payload the library reports.
 */
export function decorateExternalSource(
  source: NativeExternalDragPayload
): ExternalDragPayload {
  return {
    types: source.types,
    items: source.items,
    getStringData: (mediaType) => source.getStringData(mediaType),
    containsFiles: () => containsFiles({ source }),
    getFiles: () => getFiles({ source }),
    containsHTML: () => containsHTML({ source }),
    getHTML: () => getHTML({ source }),
    containsText: () => containsText({ source }),
    getText: () => getText({ source }),
    containsURLs: () => containsURLs({ source }),
    getURLs: () => getURLs({ source }),
  };
}

/**
 * Whether an incoming external drag is one of the named kinds. An empty or
 * missing filter matches every external drag.
 *
 * @param accepts - The kind filter as the consumer supplied it.
 * @param source - The raw payload the underlying library reports.
 */
export function matchesExternalKind(
  accepts: ExternalDragKind | ExternalDragKind[] | undefined,
  source: NativeExternalDragPayload
) {
  const kinds = makeArray(accepts);
  if (kinds.length === 0) {
    return true;
  }
  return kinds.some((kind) => {
    const predicate = EXTERNAL_KIND_PREDICATES[kind];
    // Untyped callers can pass an unknown kind; it matches nothing.
    return predicate ? predicate({ source }) : false;
  });
}
