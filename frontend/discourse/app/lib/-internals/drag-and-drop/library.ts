import { waitForPromise } from "@ember/test-waiters";
import type { CleanupFn } from "@atlaskit/pragmatic-drag-and-drop/types";
import { isTesting } from "discourse/lib/environment";

async function load() {
  const [
    elementAdapter,
    { dropTargetForExternal },
    { monitorForExternal },
    { containsFiles },
    { containsHTML },
    { containsText },
    { containsURLs },
    { getFiles },
    { getHTML },
    { getText },
    { getURLs },
    { pointerOutsideOfPreview },
    { preventUnhandled },
    { setCustomNativeDragPreview },
    { autoScrollForElements, autoScrollWindowForElements },
    { autoScrollForExternal, autoScrollWindowForExternal },
  ] = await Promise.all([
    import("@atlaskit/pragmatic-drag-and-drop/adapter/element-adapter"),
    import("@atlaskit/pragmatic-drag-and-drop/adapter/drop-target-for-external"),
    import("@atlaskit/pragmatic-drag-and-drop/adapter/monitor-for-external"),
    import("@atlaskit/pragmatic-drag-and-drop/utils/contains-files"),
    import("@atlaskit/pragmatic-drag-and-drop/utils/contains-html"),
    import("@atlaskit/pragmatic-drag-and-drop/utils/contains-text"),
    import("@atlaskit/pragmatic-drag-and-drop/utils/contains-ur-ls"),
    import("@atlaskit/pragmatic-drag-and-drop/utils/get-files"),
    import("@atlaskit/pragmatic-drag-and-drop/utils/get-html"),
    import("@atlaskit/pragmatic-drag-and-drop/utils/get-text"),
    import("@atlaskit/pragmatic-drag-and-drop/utils/get-ur-ls"),
    import("@atlaskit/pragmatic-drag-and-drop/utils/pointer-outside-of-preview"),
    import("@atlaskit/pragmatic-drag-and-drop/utils/prevent-unhandled"),
    import("@atlaskit/pragmatic-drag-and-drop/utils/set-custom-native-drag-preview"),
    import("@atlaskit/pragmatic-drag-and-drop-auto-scroll/element"),
    import("@atlaskit/pragmatic-drag-and-drop-auto-scroll/external"),
  ]);

  return {
    draggable: elementAdapter.draggable,
    dropTargetForElements: elementAdapter.dropTargetForElements,
    monitorForElements: elementAdapter.monitorForElements,
    dropTargetForExternal,
    monitorForExternal,
    containsFiles,
    containsHTML,
    containsText,
    containsURLs,
    getFiles,
    getHTML,
    getText,
    getURLs,
    pointerOutsideOfPreview,
    preventUnhandled,
    setCustomNativeDragPreview,
    autoScrollForElements,
    autoScrollWindowForElements,
    autoScrollForExternal,
    autoScrollWindowForExternal,
  };
}

/** The drag-and-drop library's functions, once loaded. */
export type DragAndDropLibrary = Awaited<ReturnType<typeof load>>;

let loading: Promise<DragAndDropLibrary> | null = null;
let loaded: DragAndDropLibrary | null = null;

/**
 * Loads the drag-and-drop library on first use. Every caller shares one load,
 * and a failed load is retried by the next caller.
 */
export function loadDragAndDropLibrary(): Promise<DragAndDropLibrary> {
  loading ??= waitForPromise(
    load().then(
      (library) => (loaded = library),
      (error) => {
        loading = null;
        throw error;
      }
    )
  );
  return loading;
}

/**
 * The loaded library, for code that only runs while a drag the library
 * dispatched is in flight. Throws before the first load has finished.
 */
export function loadedDragAndDropLibrary(): DragAndDropLibrary {
  if (!loaded) {
    throw new Error("The drag-and-drop library has not loaded yet");
  }
  return loaded;
}

const INTERACTION_EVENTS = [
  "pointerdown",
  "touchstart",
  "keydown",
  "dragenter",
];

let wanted: Promise<DragAndDropLibrary> | null = null;

// No drag can start before the user touches the page, so the library waits for
// the first interaction. Tests load it at once, so `settled()` covers it.
function loadOnFirstInteraction(): Promise<DragAndDropLibrary> {
  if (loading || isTesting()) {
    return loadDragAndDropLibrary();
  }

  wanted ??= new Promise((resolve) => {
    const start = () => {
      for (const name of INTERACTION_EVENTS) {
        document.removeEventListener(name, start, true);
      }
      resolve(loadDragAndDropLibrary());
    };
    for (const name of INTERACTION_EVENTS) {
      document.addEventListener(name, start, { capture: true, passive: true });
    }
  });

  return wanted;
}

/**
 * Registers with the library once it has loaded, and returns a cleanup that
 * either tears the registration down or, before the load has finished, stops
 * it from being made. Registrations are made in the order they were requested.
 *
 * @param register - Makes the registration and returns its cleanup.
 */
export function registerWhenLoaded(
  register: (library: DragAndDropLibrary) => CleanupFn
): CleanupFn {
  let cleanup: CleanupFn | null = null;
  let tornDown = false;

  loadOnFirstInteraction().then((library) => {
    if (!tornDown) {
      cleanup = register(library);
    }
  });

  return () => {
    tornDown = true;
    cleanup?.();
    cleanup = null;
  };
}
