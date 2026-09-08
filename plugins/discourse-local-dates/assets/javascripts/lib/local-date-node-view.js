import { iconHTML } from "discourse/lib/icon-library";
import { i18n } from "discourse-i18n";
import LocalDatesCreateModal from "../discourse/components/modal/local-dates-create";

const DATE_NODE_TYPES = ["local_date", "local_date_range"];
const EDIT_BUTTON_CLASS = "composer-local-date__edit-button";

function nodeToInitialValues(node) {
  const attrs = node.attrs;
  const isRange = node.type.name === "local_date_range";

  return {
    date: isRange ? attrs.fromDate : attrs.date,
    time: isRange ? attrs.fromTime : attrs.time,
    toDate: isRange ? attrs.toDate : null,
    toTime: isRange ? attrs.toTime : null,
    timezone: attrs.timezone,
    format: attrs.format,
    timezones: attrs.timezones ? attrs.timezones.split("|") : [],
    recurring: isRange ? null : attrs.recurring,
    countdown: attrs.countdown,
    displayedTimezone: attrs.displayedTimezone,
  };
}

class LocalDateNodeView {
  dom;

  #node;
  #view;
  #getPos;
  #getContext;
  #convertFromMarkdown;
  #NodeSelection;
  #DOMSerializer;
  #editButton;

  #returnFocusToEditor = (event) => {
    if (event.key !== "Tab") {
      return;
    }

    event.preventDefault();
    this.#view.focus();
  };

  #openEditModal = (event) => {
    event.preventDefault();
    event.stopPropagation();

    const { modal } = this.#getContext();
    modal.show(LocalDatesCreateModal, {
      model: {
        initialValues: nodeToInitialValues(this.#node),
        insertDate: (markup) => this.#applyEdit(markup),
      },
    });
  };

  constructor({
    node,
    view,
    getPos,
    getContext,
    convertFromMarkdown,
    NodeSelection,
    DOMSerializer,
  }) {
    this.#node = node;
    this.#view = view;
    this.#getPos = getPos;
    this.#getContext = getContext;
    this.#convertFromMarkdown = convertFromMarkdown;
    this.#NodeSelection = NodeSelection;
    this.#DOMSerializer = DOMSerializer;

    this.dom = document.createElement("span");
    this.dom.classList.add("composer-local-date");
    this.dom.setAttribute("contenteditable", "false");

    this.#editButton = document.createElement("button");
    this.#editButton.type = "button";
    this.#editButton.classList.add(EDIT_BUTTON_CLASS);
    this.#editButton.innerHTML = iconHTML("pencil");
    this.#editButton.addEventListener("click", this.#openEditModal);
    this.#editButton.addEventListener("keydown", this.#returnFocusToEditor);

    this.#render();
  }

  update(node) {
    const changed = !this.#node.sameMarkup(node);
    this.#node = node;

    if (changed) {
      this.#render();
    }

    return true;
  }

  selectNode() {
    this.dom.classList.add("ProseMirror-selectednode");
  }

  deselectNode() {
    this.dom.classList.remove("ProseMirror-selectednode");
  }

  stopEvent(event) {
    return this.#editButton.contains(event.target);
  }

  ignoreMutation() {
    return true;
  }

  destroy() {
    this.#editButton.removeEventListener("click", this.#openEditModal);
    this.#editButton.removeEventListener("keydown", this.#returnFocusToEditor);
  }

  /** Renders via the node spec's toDOM, so the chip matches what the schema serializes. */
  #render() {
    const { dom } = this.#DOMSerializer.renderSpec(
      document,
      this.#node.type.spec.toDOM(this.#node)
    );

    this.dom.replaceChildren(dom, this.#editButton);

    // names the date it edits, so several chips are told apart when read aloud
    const label = i18n("discourse_local_dates.edit_date", {
      date: dom.textContent.trim(),
    });
    this.#editButton.setAttribute("title", label);
    this.#editButton.setAttribute("aria-label", label);
  }

  #applyEdit(markup) {
    const pos = this.#getPos();

    if (pos === undefined) {
      return;
    }

    // the modal hands back a single date bbcode, so it parses to one paragraph
    const content = this.#convertFromMarkdown(markup).firstChild?.content;

    if (!content) {
      return;
    }

    const tr = this.#view.state.tr.replaceWith(
      pos,
      pos + this.#node.nodeSize,
      content
    );
    tr.setSelection(this.#NodeSelection.create(tr.doc, pos));
    this.#view.dispatch(tr);
    this.#view.focus();
  }
}

export default function createLocalDateNodeView({
  getContext,
  utils: { convertFromMarkdown },
  pmState: { NodeSelection },
  pmModel: { DOMSerializer },
}) {
  return (node, view, getPos) =>
    new LocalDateNodeView({
      node,
      view,
      getPos,
      getContext,
      convertFromMarkdown,
      NodeSelection,
      DOMSerializer,
    });
}

/**
 * Tab is bound by the composer, so a selected chip's edit button would
 * otherwise be unreachable without a mouse.
 */
export function focusEditButtonPlugin({ pmState: { Plugin, NodeSelection } }) {
  return new Plugin({
    props: {
      handleKeyDown(view, event) {
        if (event.key !== "Tab" || event.shiftKey) {
          return false;
        }

        const { selection } = view.state;

        if (
          !(selection instanceof NodeSelection) ||
          !DATE_NODE_TYPES.includes(selection.node.type.name)
        ) {
          return false;
        }

        const button = view
          .nodeDOM(selection.from)
          ?.querySelector?.(`.${EDIT_BUTTON_CLASS}`);

        if (!button) {
          return false;
        }

        button.focus();

        return true;
      },
    },
  });
}
