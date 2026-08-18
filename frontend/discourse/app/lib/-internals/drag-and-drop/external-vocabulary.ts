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
import { toAcceptList } from "discourse/lib/-internals/drag-and-drop/vocabulary";

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
   * The `DataTransferItem` list snapshotted at drag start. Browsers expose `kind`
   * and `type` here even when `dataTransfer.getData(…)` is blocked during
   * `dragover` for security.
   */
  items: DataTransferItem[];

  /**
   * Reads the string payload for a given MIME type. Returns `null` when the type
   * is absent or the browser withholds string data during the current drag
   * phase; completed drop callbacks normally receive the readable payload.
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
 * Vocabulary `accepts` / `acceptsExternal()` understand. Each key delegates to
 * the matching native-payload predicate so the service and external-target
 * surfaces share one vocabulary.
 */
export const EXTERNAL_KIND_PREDICATES = Object.freeze({
  files: containsFiles,
  html: containsHTML,
  text: containsText,
  urls: containsURLs,
});

/** A kind of external payload, as named by `accepts` / `acceptsExternal()`. */
export type ExternalDragKind = keyof typeof EXTERNAL_KIND_PREDICATES;

/**
 * Wraps the underlying library's raw external payload
 * (`{types, items, getStringData}`) with the `contains*` / `get*` helpers bound
 * to it, so a consumer calls `source.getFiles()` rather than importing the
 * library's helpers itself.
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
 * Whether an incoming external drag is one of the named kinds.
 *
 * An empty or missing filter matches every external drag, mirroring how the
 * element target treats an absent `accepts`. Shared so everything filtering on
 * this vocabulary agrees on what a kind name means; the element-side
 * counterpart is `matchesDragType`.
 *
 * @param accepts - The kind filter as the consumer supplied it.
 * @param source - The raw payload the underlying library reports.
 */
export function matchesExternalKind(
  accepts: ExternalDragKind | ExternalDragKind[] | undefined,
  source: NativeExternalDragPayload
) {
  const kinds = toAcceptList(accepts);
  if (kinds.length === 0) {
    return true;
  }
  return kinds.some((kind) => {
    const predicate = EXTERNAL_KIND_PREDICATES[kind];
    // Unknown kind names fail closed — better than silently matching.
    return predicate ? predicate({ source }) : false;
  });
}
