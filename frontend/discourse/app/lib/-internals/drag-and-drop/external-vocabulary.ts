import type {
  ExternalDragPayload as NativeExternalDragPayload,
  NativeMediaType,
} from "@atlaskit/pragmatic-drag-and-drop/adapter/external-adapter-types";
import { loadedDragAndDropLibrary } from "discourse/lib/-internals/drag-and-drop/library";
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
  files: "containsFiles",
  html: "containsHTML",
  text: "containsText",
  urls: "containsURLs",
} as const);

/** A kind of external payload, as named by `accepts` / `acceptsExternal()`. */
export type ExternalDragKind = keyof typeof EXTERNAL_KIND_PREDICATES;

/**
 * Binds the read helpers to the library's raw external payload. A payload
 * only exists once the library has dispatched a drag, so the library has
 * loaded by the time any helper runs.
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
    containsFiles: () => loadedDragAndDropLibrary().containsFiles({ source }),
    getFiles: () => loadedDragAndDropLibrary().getFiles({ source }),
    containsHTML: () => loadedDragAndDropLibrary().containsHTML({ source }),
    getHTML: () => loadedDragAndDropLibrary().getHTML({ source }),
    containsText: () => loadedDragAndDropLibrary().containsText({ source }),
    getText: () => loadedDragAndDropLibrary().getText({ source }),
    containsURLs: () => loadedDragAndDropLibrary().containsURLs({ source }),
    getURLs: () => loadedDragAndDropLibrary().getURLs({ source }),
  };
}

/**
 * Whether an incoming external drag is one of the named kinds. An empty or
 * missing filter matches every external drag; callers wanting "no kinds means
 * refuse" guard before calling.
 *
 * @param kinds - The kind filter as the consumer supplied it.
 * @param source - The raw payload the underlying library reports.
 */
export function matchesExternalKind(
  kinds: ExternalDragKind | ExternalDragKind[] | undefined,
  source: NativeExternalDragPayload
) {
  const list = makeArray(kinds);
  if (list.length === 0) {
    return true;
  }
  return list.some((kind) => {
    const predicate = EXTERNAL_KIND_PREDICATES[kind];
    // Untyped callers can pass an unknown kind; it matches nothing.
    return predicate
      ? loadedDragAndDropLibrary()[predicate]({ source })
      : false;
  });
}
