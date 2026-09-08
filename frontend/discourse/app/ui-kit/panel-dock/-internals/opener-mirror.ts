/**
 * Mirroring the little the server cannot serve a panel window.
 *
 * The window is served its own stylesheets, colour scheme, icons and root
 * classes, so what is left to carry across is only what the application derives
 * at runtime from state no server rendering the shell could be told: the CSS it
 * generates from what this page knows, the icons it has picked up since boot,
 * the root classes it writes for the viewport, and which of the two colour
 * schemes is currently live.
 *
 * Enumerated by selector on purpose. A general mirror cannot tell a stylesheet
 * the server already served from one it did not, and clones both.
 */

const GENERATED_STYLE_IDS = ["d-styles", "d-styles-block-outlets"];
const SCHEME_LINK_SELECTORS = ["link.light-scheme", "link.dark-scheme"];
const SPRITE_SOURCE_ID = "svg-sprites";
const SPRITE_TARGET_SELECTOR = ".d-panel-dock-window__sprites";

/** A live mirror from the opening page into one panel window. */
export interface OpenerMirror {
  /**
   * Stops following the opening page, leaving what has been mirrored in place.
   * Safe to call more than once.
   */
  dispose(): void;
}

/**
 * Starts mirroring the opening page's runtime-derived styling into a window.
 *
 * Every source is optional: a page that has not generated any of it yet is
 * simply mirrored as far as it goes.
 *
 * @param doc - The window's document.
 */
export function mirrorOpener(doc: Document): OpenerMirror {
  const observers: MutationObserver[] = [];
  let disposed = false;

  const watch = (
    source: Node,
    init: MutationObserverInit,
    sync: () => void
  ): void => {
    const observer = new MutationObserver(sync);
    observer.observe(source, init);
    observers.push(observer);
  };

  for (const id of GENERATED_STYLE_IDS) {
    const source = document.getElementById(id);
    if (!source) {
      continue;
    }

    const clone = doc.importNode(source, true);
    doc.head.append(clone);
    // A `textContent` assignment replaces the text node rather than editing it,
    // so watching character data alone would miss a wholesale rewrite.
    watch(
      source,
      { characterData: true, childList: true, subtree: true },
      () => {
        clone.textContent = source.textContent;
      }
    );
  }

  for (const selector of SCHEME_LINK_SELECTORS) {
    const source = document.querySelector<HTMLLinkElement>(selector);
    if (!source) {
      continue;
    }

    const clone = doc.importNode(source, true);
    doc.head.append(clone);
    // Toggling colour mode is a `media` flip on these two links, not a reload.
    watch(source, { attributeFilter: ["media"], attributes: true }, () => {
      clone.media = source.media;
    });
  }

  const spriteSource = document.getElementById(SPRITE_SOURCE_ID);
  const spriteTarget = doc.querySelector(SPRITE_TARGET_SELECTOR);
  if (spriteSource && spriteTarget) {
    const syncSprites = (): void => {
      spriteTarget.replaceChildren(
        ...Array.from(spriteSource.childNodes, (node) =>
          doc.importNode(node, true)
        )
      );
    };

    // The container exists from boot but is filled asynchronously, and grows
    // again whenever an icon outside the served bundle is first used.
    syncSprites();
    watch(spriteSource, { childList: true, subtree: true }, syncSprites);
  }

  const syncRootClasses = (): void => {
    // Only the class list: the server owns `data-d-panel-dock`, and adoption
    // depends on it.
    doc.documentElement.className = document.documentElement.className;
  };

  syncRootClasses();
  watch(
    document.documentElement,
    { attributeFilter: ["class"], attributes: true },
    syncRootClasses
  );

  return {
    dispose(): void {
      if (disposed) {
        return;
      }
      disposed = true;

      for (const observer of observers) {
        observer.disconnect();
      }
      observers.length = 0;
    },
  };
}
