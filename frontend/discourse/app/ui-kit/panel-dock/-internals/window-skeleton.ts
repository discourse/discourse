/**
 * The static shell a panel window needs before the panel's own tree is
 * rendered into it.
 *
 * The window runs no script of its own: everything inside it belongs to the
 * page that opened it, rendered across documents. So the stylesheets, icon
 * sprites and root attributes that page relies on have to be mirrored here,
 * and kept mirrored, or the panel renders unstyled and iconless in a document
 * that never boots an application to fix it.
 */

import interceptClick from "discourse/lib/intercept-click";

const COLOR_META_SELECTOR =
  "meta[name='color-scheme'], meta[name='theme-color']";
const STYLESHEET_SELECTOR = "link[rel~='stylesheet'], style";
const SPRITE_CONTAINER_ID = "svg-sprites";
const MIRRORED_NODE_SELECTOR = `${COLOR_META_SELECTOR}, ${STYLESHEET_SELECTOR}, #${SPRITE_CONTAINER_ID}`;
const REVEAL_TIMEOUT_MS = 1000;

const activeSkeletons = new WeakMap<Document, () => void>();

type MirroredElement = {
  clone: Element;
  observers: MutationObserver[];
};

/**
 * TODO(typescript-pending): Remove this boundary when the click interceptor is
 * authored in TypeScript.
 */
const handleInterceptedClick = interceptClick as (event: MouseEvent) => void;

function copyAttributes(
  source: Element,
  target: Element,
  excludedNames: ReadonlySet<string> = new Set()
): void {
  for (const attribute of Array.from(target.attributes)) {
    if (!excludedNames.has(attribute.name)) {
      target.removeAttribute(attribute.name);
    }
  }

  for (const attribute of Array.from(source.attributes)) {
    if (!excludedNames.has(attribute.name)) {
      target.setAttribute(attribute.name, attribute.value);
    }
  }
}

function createElement<K extends keyof HTMLElementTagNameMap>(
  name: K,
  className?: string
): HTMLElementTagNameMap[K] {
  const element = document.createElement(name);
  if (className) {
    element.className = className;
  }
  return element;
}

function createNote(note: PanelWindowNote): HTMLElement {
  const main = createElement("main", "d-panel-dock-window__reconnecting");
  const emptyState = createElement("div", "empty-state");
  const container = createElement(
    "div",
    "empty-state__container --text-only --panel-dock-reconnecting"
  );
  const heading = createElement("h1", "empty-state__title");
  const body = createElement("div", "empty-state__body");
  const status = createElement("p");

  heading.textContent = note.title;
  status.textContent = note.body;
  status.setAttribute("role", "status");
  body.append(status);
  emptyState.append(heading, body);
  container.append(emptyState);
  main.append(container);

  return main;
}

/** What replaces the panel when the page that owns it is no longer there. */
export interface PanelWindowNote {
  title: string;

  /** The sentence telling the reader how to get the panel back. */
  body: string;
}

/** The live shell of one panel window. */
export interface PanelWindowSkeleton {
  /** The element the panel's tree renders into. */
  readonly mount: HTMLElement;

  /**
   * Shows the given note in place of the panel, or clears it with `null`.
   *
   * The mount is hidden rather than emptied, so a tree still rendered into it
   * survives and reappears when the note is cleared.
   */
  setNote(note: PanelWindowNote | null): void;

  /**
   * Removes every observer, listener and timer this skeleton installed,
   * leaving the window's markup as it stands. Safe to call more than once.
   */
  dispose(): void;
}

/**
 * Prepares a blank window's document to host a panel.
 *
 * @param doc - The window's document, which is emptied and rewritten.
 * @param key - The panel's storage key, stamped on the document so a later
 * visit can recognize the window as this panel's own.
 * @param title - The window's title.
 */
export function writeSkeleton(
  doc: Document,
  key: string,
  title: string
): PanelWindowSkeleton {
  activeSkeletons.get(doc)?.();

  const observers = new Set<MutationObserver>();
  const listenerCleanups = new Set<() => void>();
  const mirroredMetas = new Map<Element, MirroredElement>();
  const mirroredStyles = new Map<Element, MirroredElement>();
  const excludedRootAttributes = new Set(["data-d-panel-dock"]);
  let disposed = false;
  let noteElement: HTMLElement | null = null;
  let revealPending = true;
  let revealTimer: number | undefined;
  let spriteSource: Element | null = null;
  let spriteObserver: MutationObserver | null = null;

  const syncRootAttributes = (): void => {
    copyAttributes(
      document.documentElement,
      doc.documentElement,
      excludedRootAttributes
    );
    if (revealPending) {
      doc.documentElement.style.visibility = "hidden";
    }
  };

  doc.head.replaceChildren();
  doc.body.replaceChildren();
  doc.documentElement.dataset.dPanelDock = key;
  syncRootAttributes();
  copyAttributes(document.body, doc.body);
  doc.title = title;

  const wrapper = createElement("div", "d-panel-dock-window");
  const mount = createElement("main", "d-panel-dock-window__mount");
  const menuPortals = createElement("div", "d-panel-dock-window__portals");
  const tooltipPortals = createElement("div", "d-panel-dock-window__portals");
  const sprites = createElement("div", "d-panel-dock-window__sprites");

  menuPortals.id = "d-menu-portals";
  tooltipPortals.id = "d-tooltip-portals";
  sprites.hidden = true;
  wrapper.append(mount, menuPortals, tooltipPortals, sprites);
  doc.body.append(wrapper);

  const registerObserver = (observer: MutationObserver): MutationObserver => {
    observers.add(observer);
    return observer;
  };

  const disconnectMirror = (mirror: MirroredElement): void => {
    mirror.clone.remove();
    for (const observer of mirror.observers) {
      observer.disconnect();
      observers.delete(observer);
    }
  };

  const orderHeadMirrors = (): void => {
    for (const source of document.querySelectorAll(COLOR_META_SELECTOR)) {
      const mirror = mirroredMetas.get(source);
      if (mirror) {
        doc.head.append(mirror.clone);
      }
    }

    for (const source of document.querySelectorAll(STYLESHEET_SELECTOR)) {
      const mirror = mirroredStyles.get(source);
      if (mirror) {
        doc.head.append(mirror.clone);
      }
    }
  };

  const reconcileMetas = (): boolean => {
    const sources = new Set(document.querySelectorAll(COLOR_META_SELECTOR));
    let changed = false;

    for (const [source, mirror] of mirroredMetas) {
      if (!sources.has(source)) {
        disconnectMirror(mirror);
        mirroredMetas.delete(source);
        changed = true;
      }
    }

    for (const source of sources) {
      if (mirroredMetas.has(source)) {
        continue;
      }

      const clone = source.cloneNode(true);
      if (!(clone instanceof Element)) {
        continue;
      }

      const observer = registerObserver(
        new MutationObserver(() => copyAttributes(source, clone))
      );
      observer.observe(source, {
        attributeFilter: ["content", "media", "name"],
        attributes: true,
      });
      mirroredMetas.set(source, { clone, observers: [observer] });
      changed = true;
    }

    return changed;
  };

  const syncStylesheet = (source: Element, clone: Element): void => {
    copyAttributes(source, clone);
    if (source instanceof HTMLLinkElement && clone instanceof HTMLLinkElement) {
      clone.href = source.href;
    }
    if (source instanceof HTMLStyleElement) {
      clone.textContent = source.textContent;
    }
  };

  const reconcileStyles = (): boolean => {
    const sources = new Set(document.querySelectorAll(STYLESHEET_SELECTOR));
    let changed = false;

    for (const [source, mirror] of mirroredStyles) {
      if (!sources.has(source)) {
        disconnectMirror(mirror);
        mirroredStyles.delete(source);
        changed = true;
      }
    }

    for (const source of sources) {
      if (mirroredStyles.has(source)) {
        continue;
      }

      const clone = source.cloneNode(true);
      if (!(clone instanceof Element)) {
        continue;
      }
      syncStylesheet(source, clone);

      const mirrorObservers: MutationObserver[] = [];
      if (source instanceof HTMLLinkElement) {
        const observer = registerObserver(
          new MutationObserver(() => {
            if (source.matches(STYLESHEET_SELECTOR)) {
              syncStylesheet(source, clone);
            } else if (reconcileStyles()) {
              orderHeadMirrors();
            }
          })
        );
        observer.observe(source, {
          attributeFilter: [
            "crossorigin",
            "disabled",
            "href",
            "integrity",
            "media",
            "referrerpolicy",
            "rel",
            "title",
          ],
          attributes: true,
        });
        mirrorObservers.push(observer);
      } else if (source instanceof HTMLStyleElement) {
        let textObservers: MutationObserver[] = [];
        const syncText = (): void => {
          clone.textContent = source.textContent;
        };
        const observeTextNodes = (): void => {
          for (const textObserver of textObservers) {
            textObserver.disconnect();
            observers.delete(textObserver);
          }
          textObservers = [];

          for (const child of Array.from(source.childNodes)) {
            if (child.nodeType === Node.TEXT_NODE) {
              const textObserver = registerObserver(
                new MutationObserver(syncText)
              );
              textObserver.observe(child, { characterData: true });
              textObservers.push(textObserver);
              mirrorObservers.push(textObserver);
            }
          }
        };
        const observer = registerObserver(
          new MutationObserver(() => {
            syncText();
            observeTextNodes();
          })
        );
        observer.observe(source, { childList: true });
        mirrorObservers.push(observer);
        const attributeObserver = registerObserver(
          new MutationObserver(() => copyAttributes(source, clone))
        );
        attributeObserver.observe(source, {
          attributeFilter: ["media", "nonce", "title", "type"],
          attributes: true,
        });
        mirrorObservers.push(attributeObserver);
        observeTextNodes();
      }

      mirroredStyles.set(source, { clone, observers: mirrorObservers });
      changed = true;
    }

    return changed;
  };

  const reconcileSprites = (): void => {
    const nextSource = document.getElementById(SPRITE_CONTAINER_ID);
    if (spriteSource === nextSource) {
      return;
    }

    spriteObserver?.disconnect();
    if (spriteObserver) {
      observers.delete(spriteObserver);
    }
    spriteSource = nextSource;

    const syncSprites = (): void => {
      sprites.replaceChildren(
        ...Array.from(spriteSource?.childNodes ?? [], (node) =>
          node.cloneNode(true)
        )
      );
    };

    syncSprites();
    if (spriteSource) {
      spriteObserver = registerObserver(new MutationObserver(syncSprites));
      spriteObserver.observe(spriteSource, { childList: true, subtree: true });
    } else {
      spriteObserver = null;
    }
  };

  const initialMetasChanged = reconcileMetas();
  const initialStylesChanged = reconcileStyles();
  if (initialMetasChanged || initialStylesChanged) {
    orderHeadMirrors();
  }
  reconcileSprites();

  const initialLinks = Array.from(
    mirroredStyles.values(),
    ({ clone }) => clone
  ).filter(
    (clone): clone is HTMLLinkElement => clone instanceof HTMLLinkElement
  );
  const unsettledLinks = new Set(initialLinks);
  const reveal = (): void => {
    revealPending = false;
    syncRootAttributes();
    if (revealTimer !== undefined) {
      window.clearTimeout(revealTimer);
      revealTimer = undefined;
    }
  };

  for (const link of initialLinks) {
    const settleLink = (): void => {
      if (!unsettledLinks.delete(link)) {
        return;
      }
      cleanup();
      if (unsettledLinks.size === 0) {
        reveal();
      }
    };
    const cleanup = (): void => {
      link.removeEventListener("error", settleLink);
      link.removeEventListener("load", settleLink);
    };
    link.addEventListener("error", settleLink, { once: true });
    link.addEventListener("load", settleLink, { once: true });
    listenerCleanups.add(cleanup);
  }
  if (unsettledLinks.size === 0) {
    reveal();
  } else {
    revealTimer = window.setTimeout(reveal, REVEAL_TIMEOUT_MS);
  }

  const rootObserver = registerObserver(
    new MutationObserver(syncRootAttributes)
  );
  rootObserver.observe(document.documentElement, {
    attributes: true,
    subtree: false,
  });

  const bodyObserver = registerObserver(
    new MutationObserver(() => copyAttributes(document.body, doc.body))
  );
  bodyObserver.observe(document.body, { attributes: true, subtree: false });

  const documentObserver = registerObserver(
    new MutationObserver((records) => {
      let metasAffected = false;
      let spritesAffected = false;
      let stylesAffected = false;

      const inspectNode = (node: Node): void => {
        if (!(node instanceof Element)) {
          return;
        }

        const candidates = node.matches(MIRRORED_NODE_SELECTOR)
          ? [node, ...node.querySelectorAll(MIRRORED_NODE_SELECTOR)]
          : node.querySelectorAll(MIRRORED_NODE_SELECTOR);

        for (const candidate of candidates) {
          metasAffected ||= candidate.matches(COLOR_META_SELECTOR);
          stylesAffected ||= candidate.matches(STYLESHEET_SELECTOR);
          spritesAffected ||= candidate.id === SPRITE_CONTAINER_ID;
        }
      };

      for (const record of records) {
        for (const node of record.addedNodes) {
          inspectNode(node);
        }
        for (const node of record.removedNodes) {
          inspectNode(node);
        }
      }

      const metasChanged = metasAffected ? reconcileMetas() : false;
      const stylesChanged = stylesAffected ? reconcileStyles() : false;
      if (metasChanged || stylesChanged) {
        orderHeadMirrors();
      }
      if (spritesAffected) {
        reconcileSprites();
      }
    })
  );
  documentObserver.observe(document.documentElement, {
    childList: true,
    subtree: true,
  });

  mount.addEventListener("click", handleInterceptedClick);
  listenerCleanups.add(() =>
    mount.removeEventListener("click", handleInterceptedClick)
  );

  const dispose = (): void => {
    if (disposed) {
      return;
    }
    disposed = true;

    for (const observer of observers) {
      observer.disconnect();
    }
    observers.clear();
    for (const cleanup of listenerCleanups) {
      cleanup();
    }
    listenerCleanups.clear();
    if (revealTimer !== undefined) {
      window.clearTimeout(revealTimer);
      revealTimer = undefined;
    }
    if (activeSkeletons.get(doc) === dispose) {
      activeSkeletons.delete(doc);
    }
  };

  const skeleton: PanelWindowSkeleton = {
    mount,
    setNote(note): void {
      noteElement?.remove();
      noteElement = null;

      if (note) {
        noteElement = createNote(note);
        mount.hidden = true;
        wrapper.classList.add("is-reconnecting");
        wrapper.append(noteElement);
      } else {
        mount.hidden = false;
        wrapper.classList.remove("is-reconnecting");
      }
    },
    dispose,
  };

  activeSkeletons.set(doc, dispose);
  return skeleton;
}

/**
 * The storage key the given document was prepared for.
 *
 * @returns The key, or `undefined` when the document is not a panel window —
 * which is how a freshly created window is told apart from one being adopted.
 */
export function skeletonKey(doc: Document): string | undefined {
  return doc.documentElement.dataset.dPanelDock;
}
