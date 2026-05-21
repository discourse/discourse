// @ts-check
import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import dIcon from "discourse/ui-kit/helpers/d-icon";

/**
 * Floating bubble menu that hovers above the active selection in an inline
 * rich-text editor. Mounted by `InlineEditController` when the schema
 * allows marks and the user has a non-empty selection.
 *
 * Buttons use `mousedown` (not `click`) so we can `preventDefault` and keep
 * the ProseMirror editor focused while the command runs — clicking via the
 * native button → mouseup → focus shift to the button would otherwise drop
 * the selection PM tracks.
 *
 * @typedef {Object} InlineEditToolbarState
 * @property {import("prosemirror-view").EditorView} view
 * @property {number} left            Viewport x of the selection midpoint.
 * @property {number} top             Viewport y of the selection's top edge.
 * @property {boolean} isStrongActive
 * @property {boolean} isEmActive
 * @property {boolean} isLinkActive
 */
export default class InlineEditToolbar extends Component {
  get style() {
    const { left, top } = this.args.state;
    return `left: ${left}px; top: ${top}px;`;
  }

  @action
  toggleMark(markName, event) {
    event.preventDefault();
    const { view } = this.args.state;
    const markType = view.state.schema.marks[markName];
    if (!markType) {
      return;
    }
    if (markName === "link") {
      this.#applyLink(view, markType);
      return;
    }
    const { from, to } = view.state.selection;
    const tr = view.state.tr;
    if (view.state.doc.rangeHasMark(from, to, markType)) {
      tr.removeMark(from, to, markType);
    } else {
      tr.addMark(from, to, markType.create());
    }
    view.dispatch(tr);
    view.focus();
  }

  /**
   * Prompts the author for a URL and applies (or removes) the link mark.
   * Uses a native `prompt` for v1 — admin-only flow on an alpha plugin, and
   * a styled modal would force the PM editor to lose focus while open.
   * Polish pass can swap to an inline input or a small dialog later.
   */
  #applyLink(view, markType) {
    const { from, to } = view.state.selection;
    if (from === to) {
      return;
    }
    const existing = this.#existingLinkHref(view.state, markType);
    // eslint-disable-next-line no-alert
    const url = window.prompt("Link URL", existing ?? "https://");
    if (url == null) {
      // Cancelled — leave the selection untouched.
      return;
    }
    const tr = view.state.tr;
    tr.removeMark(from, to, markType);
    if (url.trim()) {
      tr.addMark(from, to, markType.create({ href: url.trim() }));
    }
    view.dispatch(tr);
    view.focus();
  }

  #existingLinkHref(state, markType) {
    const { from, to } = state.selection;
    let href = null;
    state.doc.nodesBetween(from, to, (node) => {
      const mark = node.marks.find((m) => m.type === markType);
      if (mark && href === null) {
        href = mark.attrs?.href ?? null;
      }
    });
    return href;
  }

  <template>
    {{! mousedown (not click) is load-bearing here: it fires BEFORE focus
        shifts to the button, so combined with preventDefault the
        ProseMirror selection survives the button activation. The
        standard click event would let focus move to the button first,
        which collapses PM's selection and breaks the command. Buttons
        are also tabindex=-1 so they're not in the keyboard tab order. }}
    {{! template-lint-disable no-pointer-down-event-binding }}
    <div class="ve-inline-edit-toolbar" style={{this.style}}>
      <button
        type="button"
        tabindex="-1"
        class={{if @state.isStrongActive "--active"}}
        title="Bold (Cmd+B)"
        {{on "mousedown" (fn this.toggleMark "strong")}}
      >
        {{dIcon "bold"}}
      </button>
      <button
        type="button"
        tabindex="-1"
        class={{if @state.isEmActive "--active"}}
        title="Italic (Cmd+I)"
        {{on "mousedown" (fn this.toggleMark "em")}}
      >
        {{dIcon "italic"}}
      </button>
      <button
        type="button"
        tabindex="-1"
        class={{if @state.isLinkActive "--active"}}
        title="Link"
        {{on "mousedown" (fn this.toggleMark "link")}}
      >
        {{dIcon "link"}}
      </button>
    </div>
  </template>
}
