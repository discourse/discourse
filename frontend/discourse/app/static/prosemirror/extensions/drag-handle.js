import { NodeSelection } from "prosemirror-state";
import NodeMenu from "discourse/components/composer/node-menu";
import { nodeActionsFor } from "discourse/lib/composer/rich-editor-extensions";
import { iconElement } from "discourse/lib/icon-library";
import { registerPointerDrag } from "discourse/ui-kit/modifiers/d-pointer-drag";
import { i18n } from "discourse-i18n";
import dragAutoscroll from "../lib/drag-autoscroll";

const MENU_IDENTIFIER = "composer-node-menu";

const DESKTOP_HANDLE_OFFSET_REM = 0.5;
const DRAG_THRESHOLD = 4;
const POINTER_RELEASE_DELAY = 200;
const TOUCH_HANDLE_GAP = 6;

let handleSequence = 0;

// macOS has neither a ContextMenu key nor F-keys that reach the page by
// default, so Alt+Enter carries the same meaning there.
function opensMenu(event) {
  return (
    event.key === "ContextMenu" ||
    (event.key === "F10" && event.shiftKey) ||
    (event.key === "Enter" && event.altKey && !event.ctrlKey && !event.metaKey)
  );
}

/**
 * A grip beside the block under the pointer, for dragging that block elsewhere
 * or opening the actions registered for it.
 *
 * The handle lives outside the editable element, so it captures the pointer and
 * moves the selected block directly when the pointer is released.
 */
class DragHandleView {
  #view;
  #pluginParams;
  #NodeSelection;
  #touchFirst;
  #previousAriaKeyShortcuts;
  #pointerTarget = null;
  #pointerReleaseTimer = null;
  #caretTarget = null;
  #target = null;
  #menu = null;
  #openingMenu = false;
  #dragOffsetY = null;
  #dragTarget = null;
  #dragAutoscroll = null;
  #lastDragEvent = null;
  #dropIndicator;
  #dragEndedAt = null;
  #cleanupPointerDrag;
  #destroyed = false;

  // The handle lives outside the editable element, so reaching for it fires
  // `pointerleave` on the editor. Dropping the target there would make the
  // handle impossible to click.
  #releasePointer = (event) => {
    const to = event?.relatedTarget;
    if (
      to instanceof Node &&
      (this.handle.contains(to) || this.#view.dom.contains(to))
    ) {
      this.#cancelPointerRelease();
      return;
    }

    this.#cancelPointerRelease();
    this.#pointerReleaseTimer = window.setTimeout(() => {
      this.#pointerReleaseTimer = null;
      this.#pointerTarget = null;
      this.#render();
    }, POINTER_RELEASE_DELAY);
  };

  #holdPointer = () => this.#cancelPointerRelease();

  #releaseFocus = (event) => {
    if (event.relatedTarget === this.handle) {
      return;
    }

    this.#render();
  };

  #track = (event) => {
    if (!this.#view.editable || this.#menu?.expanded) {
      return;
    }

    this.#cancelPointerRelease();
    if (this.#pointerInTargetCorridor(event)) {
      return;
    }

    this.#pointerTarget = this.#blockAt(event);
    this.#render();
  };

  #onViewportChange = () => {
    if (this.#dragTarget && this.#lastDragEvent) {
      this.#placeDraggedHandle(this.#lastDragEvent);
      this.#showDropIndicator(this.#lastDragEvent);
      return;
    }

    this.#cancelPointerRelease();
    this.#pointerTarget = null;
    this.#hideDropIndicator();
    this.#render();
  };

  #render = () => {
    if (
      this.#destroyed ||
      this.#dragTarget ||
      this.#openingMenu ||
      this.#menu?.expanded
    ) {
      return;
    }

    const target = this.#view.editable
      ? (this.#pointerTarget ??
        (this.#touchFirst || this.handle.matches(":focus")
          ? this.#caretTarget
          : null))
      : null;

    this.#target = target;

    if (!target) {
      this.#hideHandle();
      return;
    }

    this.handle.tabIndex = 0;
    this.handle.setAttribute("aria-hidden", "false");
    this.#place(target);
  };

  #onDragStart = (event) => {
    if (!this.#view.editable || !this.#target) {
      return false;
    }

    this.#cancelPointerRelease();
    const bounds = this.handle.getBoundingClientRect();
    this.#dragTarget = this.#target;
    this.#dragOffsetY = event.clientY - bounds.top;
  };

  #onDrag = (event) => {
    if (this.#dragOffsetY === null || !this.#dragTarget) {
      return;
    }

    if (!this.handle.classList.contains("is-dragging")) {
      this.#select(this.#dragTarget);
      this.#view.dom.classList.add("is-dragging-block");
      this.handle.classList.add("is-dragging", "--visible");
      this.#pointerTarget = null;
      this.#dragAutoscroll = dragAutoscroll(
        this.#view.dom.parentElement ?? this.#view.dom,
        "Y",
        () => {
          if (this.#lastDragEvent) {
            this.#placeDraggedHandle(this.#lastDragEvent);
            this.#showDropIndicator(this.#lastDragEvent);
          }
        }
      );
    }

    this.#lastDragEvent = event;
    this.#placeDraggedHandle(event);
    this.#showDropIndicator(event);
    this.#dragAutoscroll?.update(event);
  };

  #onDragEnd = (event, info) => {
    if (info.moved) {
      this.#moveTo(this.#dropAt(event));
      this.#dragEndedAt = event.timeStamp;
    }
    this.#finishDrag();
  };

  #onDragCancel = () => {
    this.#finishDrag();
  };

  #onClick = async (event) => {
    if (
      this.#dragEndedAt !== null &&
      event.timeStamp - this.#dragEndedAt < 500
    ) {
      this.#dragEndedAt = null;
      return;
    }

    this.#dragEndedAt = null;
    await this.openMenu();
  };

  constructor(view, pluginParams) {
    this.#view = view;
    this.#pluginParams = pluginParams;
    this.#NodeSelection = pluginParams.pmState.NodeSelection;
    this.#touchFirst = this.#pluginParams.getContext().capabilities.touchFirst;
    this.#previousAriaKeyShortcuts = view.dom.getAttribute("aria-keyshortcuts");

    const editorShortcuts = new Set(
      (this.#previousAriaKeyShortcuts ?? "").split(/\s+/).filter(Boolean)
    );
    editorShortcuts.add("Alt+Enter");
    editorShortcuts.add("Shift+F10");
    view.dom.setAttribute("aria-keyshortcuts", [...editorShortcuts].join(" "));

    this.handle = document.createElement("button");
    this.handle.type = "button";
    this.handle.className = "composer-drag-handle";
    this.handle.tabIndex = -1;
    this.handle.setAttribute("aria-label", i18n("composer.node.handle"));
    this.handle.setAttribute("aria-keyshortcuts", "Alt+Enter Shift+F10");
    this.handle.setAttribute("aria-expanded", "false");
    this.handle.setAttribute("aria-hidden", "true");
    this.handle.id = `${MENU_IDENTIFIER}-trigger-${++handleSequence}`;
    this.handle.classList.toggle("--touch", this.#touchFirst);
    this.handle.appendChild(iconElement("grip-vertical"));

    this.#dropIndicator = document.createElement("div");
    this.#dropIndicator.className = "composer-drag-handle__drop-indicator";
    this.#dropIndicator.setAttribute("aria-hidden", "true");

    this.handle.addEventListener("click", this.#onClick);
    this.#cleanupPointerDrag = registerPointerDrag(this.handle, () => ({
      onDragStart: this.#onDragStart,
      onDrag: this.#onDrag,
      onDragEnd: this.#onDragEnd,
      onDragCancel: this.#onDragCancel,
      threshold: DRAG_THRESHOLD,
    }));

    view.dom.parentElement?.append(this.handle, this.#dropIndicator);
    view.dom.addEventListener("pointermove", this.#track);
    view.dom.addEventListener("pointerleave", this.#releasePointer);
    view.dom.addEventListener("blur", this.#releaseFocus);
    view.dom.addEventListener("focus", this.#render);
    this.handle.addEventListener("blur", this.#render);
    this.handle.addEventListener("pointerenter", this.#holdPointer);
    this.handle.addEventListener("pointerleave", this.#releasePointer);
    window.addEventListener("scroll", this.#onViewportChange, {
      capture: true,
      passive: true,
    });
    window.addEventListener("resize", this.#onViewportChange, {
      passive: true,
    });
  }

  async openMenu({ fromCaret = false } = {}) {
    if (this.#destroyed || !this.#view.editable || this.#openingMenu) {
      return;
    }

    this.#openingMenu = true;

    try {
      if (fromCaret) {
        this.#target = this.#caretTarget;
        if (this.#target) {
          this.#place(this.#target);
        }
      } else if (!this.#target && this.#caretTarget) {
        this.#target = this.#caretTarget;
        this.#place(this.#target);
      }

      const target = this.#select();
      if (!target) {
        return;
      }

      const items = nodeActionsFor(
        target.node.type.name,
        {
          node: target.node,
          pos: target.pos,
          view: this.#view,
          pluginParams: this.#pluginParams,
        },
        this.#pluginParams.extensions
      );

      if (!items.length) {
        this.#view.focus();
        return;
      }

      const context = this.#pluginParams.getContext();
      let closed = false;
      const menu = await context.menu.show(this.handle, {
        identifier: MENU_IDENTIFIER,
        component: NodeMenu,
        placement: "bottom-start",
        contentRole: "none",
        modalForMobile: true,
        autofocus: true,
        trapTab: true,
        onClose: () => {
          closed = true;
          if (!this.#destroyed) {
            this.handle.setAttribute("aria-expanded", "false");
            this.#menu = null;
            this.#view.focus();
          }
        },
        data: {
          className: MENU_IDENTIFIER,
          items,
          run: (item) => {
            this.#menu?.close();
            item.action?.();
            if (item.announcement) {
              context.a11y.announce(item.announcement);
            }
          },
        },
      });

      if (this.#destroyed || closed) {
        menu?.destroy?.();
        return;
      }

      this.#menu = menu;

      this.handle.setAttribute(
        "aria-expanded",
        this.#menu?.expanded ? "true" : "false"
      );
    } finally {
      this.#openingMenu = false;
      if (!this.#destroyed) {
        this.#render();
      }
    }
  }

  /** The current block used by touch placement and keyboard commands. */
  syncCaret() {
    if (this.#openingMenu || this.#menu?.expanded) {
      return;
    }

    const { selection } = this.#view.state;
    if (!this.#view.editable) {
      this.#caretTarget = null;
    } else if (selection instanceof this.#NodeSelection) {
      this.#caretTarget = this.#resolveAt(selection.from);
    } else {
      this.#caretTarget =
        selection.$from.depth !== 0
          ? this.#resolveBlockAt(selection.$from)
          : null;
    }
    this.#render();
  }

  destroy() {
    this.#destroyed = true;
    this.#cancelPointerRelease();
    this.#finishDrag();
    this.#cleanupPointerDrag();
    this.#menu?.destroy?.();
    this.handle.remove();
    this.#dropIndicator.remove();
    this.handle.removeEventListener("click", this.#onClick);
    this.#view.dom.removeEventListener("pointermove", this.#track);
    this.#view.dom.removeEventListener("pointerleave", this.#releasePointer);
    this.#view.dom.removeEventListener("blur", this.#releaseFocus);
    this.#view.dom.removeEventListener("focus", this.#render);
    this.handle.removeEventListener("blur", this.#render);
    this.handle.removeEventListener("pointerenter", this.#holdPointer);
    this.handle.removeEventListener("pointerleave", this.#releasePointer);
    window.removeEventListener("scroll", this.#onViewportChange, true);
    window.removeEventListener("resize", this.#onViewportChange);
    if (this.#previousAriaKeyShortcuts === null) {
      this.#view.dom.removeAttribute("aria-keyshortcuts");
    } else {
      this.#view.dom.setAttribute(
        "aria-keyshortcuts",
        this.#previousAriaKeyShortcuts
      );
    }
  }

  #finishDrag() {
    this.#dragAutoscroll?.stop();
    this.#dragAutoscroll = null;
    this.#lastDragEvent = null;
    this.#dragOffsetY = null;
    this.#dragTarget = null;
    this.#hideDropIndicator();
    this.#view.dom.classList.remove("is-dragging-block");
    this.handle.classList.remove("is-dragging");
    this.#render();
  }

  /** The root block or deepest list item under the pointer. */
  #blockAt(event) {
    const found = this.#view.posAtCoords({
      left: event.clientX,
      top: event.clientY,
    });
    if (found) {
      const { doc } = this.#view.state;
      const $pos = doc.resolve(Math.min(found.pos, doc.content.size));
      if ($pos.depth !== 0) {
        const target = this.#resolveBlockAt($pos);
        if (target) {
          return target;
        }
      }
    }

    return this.#nearestBlockAt(event.clientX, event.clientY);
  }

  #cancelPointerRelease() {
    if (this.#pointerReleaseTimer !== null) {
      window.clearTimeout(this.#pointerReleaseTimer);
      this.#pointerReleaseTimer = null;
    }
  }

  #dropAt(event) {
    const source = this.#dragTarget;
    const target = this.#blockAt(event);
    if (!source || !target) {
      return null;
    }
    if (
      target.pos >= source.pos &&
      target.pos < source.pos + source.node.nodeSize
    ) {
      return null;
    }

    const { doc } = this.#view.state;
    const sourceParent = doc.resolve(source.pos).parent;
    const $target = doc.resolve(target.pos);
    const targetBounds = target.dom.getBoundingClientRect();
    const after = event.clientY >= targetBounds.top + targetBounds.height / 2;
    const targetIndex = $target.index() + (after ? 1 : 0);
    if (
      !$target.parent.canReplaceWith(
        targetIndex,
        targetIndex,
        source.node.type,
        source.node.marks
      )
    ) {
      return null;
    }

    const insertPos = target.pos + (after ? target.node.nodeSize : 0);
    let projectedInsertPos = insertPos;

    if (sourceParent === $target.parent && projectedInsertPos > source.pos) {
      projectedInsertPos -= source.node.nodeSize;
    }
    if (sourceParent === $target.parent && projectedInsertPos === source.pos) {
      return null;
    }

    return {
      insertPos,
      left: targetBounds.left,
      top: after ? targetBounds.bottom : targetBounds.top,
      width: targetBounds.width,
    };
  }

  #hideDropIndicator() {
    this.#dropIndicator.classList.remove("--visible");
  }

  #hideHandle() {
    this.handle.classList.remove("--visible");
    this.handle.tabIndex = -1;
    this.handle.setAttribute("aria-hidden", "true");
  }

  #place(target) {
    const anchor = this.#placementAnchor(target);
    const block = anchor.dom.getBoundingClientRect();
    const editor = this.#view.dom.getBoundingClientRect();
    const isRoot = this.#view.state.doc.resolve(target.pos).depth === 0;
    const direction = getComputedStyle(this.#view.dom).direction;

    // Aligned to the block's first line rather than its middle, so a tall block
    // does not park the handle halfway down the page.
    const style = getComputedStyle(anchor.dom);
    const line =
      parseFloat(style.lineHeight) ||
      parseFloat(style.fontSize) * 1.2 ||
      block.height;

    const top = block.top + Math.max(line - this.handle.offsetHeight, 0) / 2;
    const viewport = this.#visibleEditorBounds(editor);
    if (
      top < viewport.top ||
      top + this.handle.offsetHeight > viewport.bottom
    ) {
      this.#hideHandle();
      return;
    }

    this.handle.style.top = `${top}px`;
    const left = this.#touchFirst
      ? direction === "rtl"
        ? Math.max(block.left, editor.left) + TOUCH_HANDLE_GAP
        : Math.min(block.right, editor.right) -
          this.handle.offsetWidth -
          TOUCH_HANDLE_GAP
      : this.#desktopHandleLeft({ anchor, block, direction, editor, isRoot });

    this.handle.style.left = `${left}px`;
    this.handle.classList.add("--visible");
  }

  #desktopHandleLeft({ anchor, block, direction, editor, isRoot }) {
    const offset = this.#desktopHandleOffset();

    if (anchor.listItem) {
      const markerInset = this.#listMarkerInset(anchor.listItem, direction);

      return direction === "rtl"
        ? block.right + markerInset + offset
        : block.left - markerInset - this.handle.offsetWidth - offset;
    }

    return direction === "rtl"
      ? (isRoot ? editor.right : block.right) - this.handle.offsetWidth + offset
      : (isRoot ? editor.left : block.left) - offset;
  }

  #listMarkerInset(listItem, direction) {
    const list = listItem.parentElement;
    if (!list) {
      return 0;
    }

    const style = getComputedStyle(list);
    const padding = parseFloat(
      direction === "rtl" ? style.paddingRight : style.paddingLeft
    );

    return padding || parseFloat(style.fontSize) * 1.25 || 0;
  }

  #placementAnchor(target) {
    const { schema } = this.#view.state;
    const isList =
      target.node.type === schema.nodes.bullet_list ||
      target.node.type === schema.nodes.ordered_list;
    const firstItem = isList
      ? Array.from(target.dom.children).find((child) => child.matches("li"))
      : null;
    const dom = firstItem instanceof HTMLElement ? firstItem : target.dom;

    return {
      dom,
      listItem:
        dom.matches("li") &&
        (isList || target.node.type === schema.nodes.list_item)
          ? dom
          : null,
    };
  }

  #pointerInTargetCorridor(event) {
    if (!this.#pointerTarget || !this.handle.matches(".--visible")) {
      return false;
    }

    const anchor = this.#placementAnchor(this.#pointerTarget);
    const block = anchor.dom.getBoundingClientRect();
    const style = getComputedStyle(anchor.dom);
    const line =
      parseFloat(style.lineHeight) ||
      parseFloat(style.fontSize) * 1.2 ||
      block.height;
    const handleLeft = parseFloat(this.handle.style.left);
    const handleTop = parseFloat(this.handle.style.top);
    const contentEdge =
      getComputedStyle(this.#view.dom).direction === "rtl"
        ? block.right
        : block.left;

    return (
      event.clientX >= Math.min(handleLeft, contentEdge) &&
      event.clientX <=
        Math.max(handleLeft + this.handle.offsetWidth, contentEdge) &&
      event.clientY >= Math.min(handleTop, block.top) &&
      event.clientY <=
        Math.max(handleTop + this.handle.offsetHeight, block.top + line)
    );
  }

  #visibleEditorBounds(editor) {
    const scrollport = this.#view.dom.parentElement;
    if (!scrollport) {
      return editor;
    }

    const bounds = scrollport.getBoundingClientRect();
    const top = bounds.top + scrollport.clientTop;

    return {
      top,
      bottom: top + (scrollport.clientHeight || bounds.height),
    };
  }

  #placeDraggedHandle(event) {
    const editor = this.#view.dom.getBoundingClientRect();
    const handle = this.handle.getBoundingClientRect();
    const top = Math.min(
      Math.max(event.clientY - this.#dragOffsetY, editor.top),
      Math.max(editor.top, editor.bottom - handle.height)
    );

    this.handle.style.top = `${top}px`;
  }

  #desktopHandleOffset() {
    const rootFontSize = parseFloat(
      getComputedStyle(document.documentElement).fontSize
    );
    return (rootFontSize || 16) * DESKTOP_HANDLE_OFFSET_REM;
  }

  #moveTo(dropTarget) {
    const source = this.#dragTarget;
    if (!source || !dropTarget) {
      return;
    }

    const tr = this.#view.state.tr.deleteRange(
      source.pos,
      source.pos + source.node.nodeSize
    );
    if (!tr.steps.length) {
      return;
    }

    const insertPos = tr.mapping.map(dropTarget.insertPos);
    const $insert = tr.doc.resolve(insertPos);
    if (
      !$insert.parent.canReplaceWith(
        $insert.index(),
        $insert.index(),
        source.node.type,
        source.node.marks
      )
    ) {
      return;
    }

    tr.insert(insertPos, source.node);
    tr.setSelection(this.#NodeSelection.create(tr.doc, insertPos));
    this.#view.dispatch(tr.scrollIntoView());
    this.#view.focus();
  }

  #showDropIndicator(event) {
    const dropTarget = this.#dropAt(event);
    if (!dropTarget) {
      this.#hideDropIndicator();
      return;
    }

    this.#dropIndicator.style.left = `${dropTarget.left}px`;
    this.#dropIndicator.style.top = `${dropTarget.top}px`;
    this.#dropIndicator.style.width = `${dropTarget.width}px`;
    this.#dropIndicator.classList.add("--visible");
  }

  #nearestBlockAt(x, y) {
    const editorBounds = this.#view.dom.getBoundingClientRect();
    if (y < editorBounds.top || y > editorBounds.bottom) {
      return null;
    }

    let closest = null;
    let closestDistance = Infinity;
    let closestDepth = -1;
    const { doc, schema } = this.#view.state;

    doc.descendants((node, pos, parent) => {
      if (parent !== doc && node.type !== schema.nodes.list_item) {
        return;
      }

      const dom = this.#view.nodeDOM(pos);
      if (!(dom instanceof HTMLElement)) {
        return;
      }

      const bounds = dom.getBoundingClientRect();
      const verticalDistance =
        y < bounds.top
          ? bounds.top - y
          : y > bounds.bottom
            ? y - bounds.bottom
            : 0;
      const horizontalDistance =
        x < bounds.left
          ? bounds.left - x
          : x > bounds.right
            ? x - bounds.right
            : 0;
      const distance = Math.hypot(horizontalDistance, verticalDistance);
      const depth = doc.resolve(pos).depth + 1;
      if (
        distance < closestDistance ||
        (distance === closestDistance && depth > closestDepth)
      ) {
        closest = { node, pos, dom };
        closestDistance = distance;
        closestDepth = depth;
      }
    });

    return closest;
  }

  #resolveBlockAt($pos) {
    for (let depth = $pos.depth; depth > 0; depth--) {
      const target = this.#resolveAt($pos.before(depth));
      if (
        target &&
        (target.node.type === this.#view.state.schema.nodes.list_item ||
          depth === 1)
      ) {
        return target;
      }
    }

    return null;
  }

  #resolveAt(pos) {
    const node = this.#view.state.doc.nodeAt(pos);
    const dom = this.#view.nodeDOM(pos);

    return node && dom instanceof HTMLElement ? { node, pos, dom } : null;
  }

  #select(target = this.#target) {
    if (!this.#view.editable || !target) {
      return null;
    }

    const { state, dispatch } = this.#view;
    dispatch(
      state.tr.setSelection(this.#NodeSelection.create(state.doc, target.pos))
    );
    return target;
  }
}

function sharedNodeActions(params) {
  const { node, pos, view } = params;
  const $pos = view.state.doc.resolve(pos);
  const index = $pos.index();
  const actions = [];

  if (index > 0) {
    actions.push({
      icon: "arrow-up",
      label: i18n("composer.node.move_up"),
      className: "composer-node-menu__move-up",
      announcement: i18n("composer.node.moved_up"),
      action: () => moveBlock(params, -1),
    });
  }
  if (index < $pos.parent.childCount - 1) {
    actions.push({
      icon: "arrow-down",
      label: i18n("composer.node.move_down"),
      className: "composer-node-menu__move-down",
      announcement: i18n("composer.node.moved_down"),
      action: () => moveBlock(params, 1),
    });
  }

  actions.push(
    {
      icon: "copy",
      label: i18n("composer.node.duplicate"),
      className: "composer-node-menu__duplicate",
      announcement: i18n("composer.node.duplicated"),
      action: () => {
        if (view.editable) {
          view.dispatch(view.state.tr.insert(pos + node.nodeSize, node));
          view.focus();
        }
      },
    },
    { divider: true },
    {
      icon: "trash-can",
      label: i18n("composer.node.delete"),
      className: "composer-node-menu__delete",
      announcement: i18n("composer.node.deleted"),
      dangerous: true,
      action: () => {
        if (view.editable) {
          view.dispatch(view.state.tr.delete(pos, pos + node.nodeSize));
          view.focus();
        }
      },
    }
  );

  return actions;
}

function moveBlock({ node, pos, view }, direction) {
  if (!view.editable) {
    return;
  }

  const { doc } = view.state;
  const $pos = doc.resolve(pos);
  const index = $pos.index();
  const sibling = $pos.parent.maybeChild(index + direction);
  if (!sibling) {
    return;
  }

  const nextPos =
    direction < 0 ? pos - sibling.nodeSize : pos + sibling.nodeSize;
  const tr = view.state.tr
    .delete(pos, pos + node.nodeSize)
    .insert(nextPos, node);
  tr.setSelection(NodeSelection.create(tr.doc, nextPos));
  view.dispatch(tr.scrollIntoView());
  view.focus();
}

/** @type {import("discourse/lib/composer/rich-editor-extensions").RichEditorExtension} */
const extension = {
  // Actions every block gets. Node-specific ones come from the node's own
  // extension, so a plugin can contribute to the blocks it introduces.
  nodeActions: {
    "*": (params) => sharedNodeActions(params),
  },

  plugins(pluginParams) {
    const {
      pmState: { Plugin, PluginKey },
    } = pluginParams;

    let handle = null;

    return new Plugin({
      key: new PluginKey("dragHandle"),

      props: {
        // The same gesture the platform uses for "open the menu for what is
        // focused". This extension registers last, so a node with a menu of its
        // own — a table cell, say — answers first and this never fires there.
        handleKeyDown: (view, event) => {
          if (!view.editable || !opensMenu(event) || !handle) {
            return false;
          }

          event.preventDefault();
          handle.openMenu({ fromCaret: true });
          return true;
        },
      },

      view: (view) => {
        handle = new DragHandleView(view, pluginParams);

        return {
          update: () => handle.syncCaret(),
          destroy: () => {
            handle.destroy();
            handle = null;
          },
        };
      },
    });
  },
};

export default extension;
