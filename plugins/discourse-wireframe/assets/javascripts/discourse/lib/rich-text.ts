import { safeHref } from "discourse/lib/safe-href";

/*
 * Minimal structural shims for the ProseMirror surface this module touches.
 * ProseMirror ships full TypeScript types, but it is a dependency of core's
 * editor and is not resolvable from this plugin's module graph, so we describe
 * only the exact shape consumed here. The concrete objects are supplied at
 * runtime by the editor when these helpers run.
 */

/** A single ProseMirror mark instance (e.g. a `strong`/`em`/`link` span). */
interface PmMark {
  type: PmMarkType;
  attrs?: { href?: string } | null;
}

/** The type descriptor for a mark, keyed on a schema (e.g. `schema.marks.link`). */
interface PmMarkType {
  isInSet(set: readonly PmMark[] | null): PmMark | null | undefined;
}

/** A ProseMirror document/inline node, as walked by {@link existingLinkHref}. */
interface PmNode {
  marks: readonly PmMark[];
}

/** A resolved position, used to read the marks at the caret. */
interface PmResolvedPos {
  marks(): readonly PmMark[];
}

/** The current selection range on an editor state. */
interface PmSelection {
  from: number;
  to: number;
  empty: boolean;
  $from: PmResolvedPos;
}

/** The document node, exposing the range/traversal helpers used here. */
interface PmDoc {
  rangeHasMark(from: number, to: number, type: PmMarkType): boolean;
  nodesBetween(
    from: number,
    to: number,
    f: (node: PmNode) => boolean | void
  ): void;
}

/** A transaction, chained to build the `hard_break` insertion. */
interface PmTransaction {
  replaceSelectionWith(node: PmNode): PmTransaction;
  scrollIntoView(): PmTransaction;
}

/** The editor state passed into the selection-inspecting helpers. */
interface PmEditorState {
  selection: PmSelection;
  storedMarks: readonly PmMark[] | null;
  doc: PmDoc;
  tr: PmTransaction;
}

/** The type descriptor for a node, used to create a `hard_break`. */
interface PmNodeType {
  create(): PmNode;
}

/** A schema, from which node types are looked up by name. */
interface PmSchema {
  nodes: Record<string, PmNodeType | undefined>;
}

/** A ProseMirror keymap command. */
type PmCommand = (
  state: PmEditorState,
  dispatch?: (tr: PmTransaction) => void
) => boolean;

/**
 * A node in the stored doc-JSON representation. Plain strings and full
 * ProseMirror doc-JSON are the two accepted stored shapes; this describes the
 * latter (and its nested text/inline nodes).
 */
export interface RichTextDoc {
  type?: string;
  text?: string;
  content?: RichTextDoc[];
  marks?: Array<{ type: string; attrs?: { href?: string } }>;
}

/**
 * Normalize a stored value into a ProseMirror doc-JSON shape. Plain strings
 * become a doc with a single text node; existing docs pass through unchanged.
 */
export function toDoc(
  value: string | RichTextDoc | null | undefined
): RichTextDoc {
  if (value == null) {
    return { type: "doc", content: [] };
  }
  if (typeof value === "string") {
    return {
      type: "doc",
      content: value ? [{ type: "text", text: value }] : [],
    };
  }
  return value;
}

/**
 * Inverse of {@link toDoc}. Returns a plain string when the doc has no marks
 * and no hard breaks; otherwise returns the doc-JSON unchanged. This keeps
 * the common (unformatted) case as a small, hand-author-friendly string.
 */
export function toStorage(doc: RichTextDoc): string | RichTextDoc {
  if (!doc || doc.type !== "doc" || !Array.isArray(doc.content)) {
    return "";
  }
  const allPlain = doc.content.every(
    (node) => node.type === "text" && (!node.marks || node.marks.length === 0)
  );
  if (allPlain) {
    return doc.content.map((node) => node.text ?? "").join("");
  }
  return doc;
}

/**
 * Flatten an rich-text value to a single markdown string, suitable
 * for a read-only inspector summary (e.g. `"Hello **world**"`). Plain
 * strings pass through; doc-JSON is walked and marks become `**`/`*`/
 * `[text](url)` wrappers in canonical mark order.
 *
 * Not a full markdown serializer — this is one-way (no parse), and only
 * handles the three allowed marks plus `hard_break`. Used by the inspector
 * form to show authors what they've typed without rendering a parallel
 * editor.
 */
export function toFlatMarkdown(value: string | RichTextDoc): string {
  if (typeof value === "string") {
    return value;
  }
  if (!value || !Array.isArray(value.content)) {
    return "";
  }
  return value.content
    .map((node) => {
      if (node.type === "hard_break") {
        return "\n";
      }
      if (node.type !== "text") {
        return "";
      }
      let text = node.text ?? "";
      for (const mark of node.marks ?? []) {
        if (mark.type === "strong") {
          text = `**${text}**`;
        } else if (mark.type === "em") {
          text = `*${text}*`;
        } else if (mark.type === "link") {
          text = `[${text}](${mark.attrs?.href ?? ""})`;
        }
      }
      return text;
    })
    .join("");
}

/**
 * Returns `true` when the current selection has the given mark applied
 * (or, for an empty selection, when `storedMarks` carries it). Shared by
 * the canvas inline-edit controller and the inspector rich-text control.
 */
export function hasMark(
  state: PmEditorState,
  markType: PmMarkType | undefined
): boolean {
  if (!markType) {
    return false;
  }
  const { from, $from, to, empty } = state.selection;
  if (empty) {
    return !!markType.isInSet(state.storedMarks || $from.marks());
  }
  return state.doc.rangeHasMark(from, to, markType);
}

/**
 * Walks the current selection and returns the first link mark's `href`, or
 * `null` when no link mark touches the range. Used to prefill the URL input
 * when entering link-edit mode over an already-linked range.
 */
export function existingLinkHref(
  state: PmEditorState,
  markType: PmMarkType | undefined
): string | null {
  if (!markType) {
    return null;
  }
  const { from, to } = state.selection;
  let href: string | null = null;
  state.doc.nodesBetween(from, to, (node) => {
    const mark = node.marks.find((m) => m.type === markType);
    if (mark && href === null) {
      href = mark.attrs?.href ?? null;
    }
  });
  return href;
}

/**
 * Builds a ProseMirror keymap command that inserts a `hard_break` node at the
 * cursor. Used by paragraph-schema Enter / Shift+Enter handling where a soft
 * line break is the right gesture.
 */
export function insertHardBreak(schema: PmSchema): PmCommand {
  return (state, dispatch) => {
    if (!schema.nodes.hard_break) {
      return false;
    }
    const br = schema.nodes.hard_break.create();
    if (dispatch) {
      dispatch(state.tr.replaceSelectionWith(br).scrollIntoView());
    }
    return true;
  };
}

const TEXT_NODE = {
  group: "inline",
  toDOM() {
    return ["span", 0];
  },
};

const HARD_BREAK_NODE = {
  inline: true,
  group: "inline",
  selectable: false,
  parseDOM: [{ tag: "br" }],
  toDOM() {
    return ["br"];
  },
};

const STRONG_MARK = {
  parseDOM: [
    { tag: "strong" },
    {
      tag: "b",
      getAttrs: (n: HTMLElement) => n.style.fontWeight !== "normal" && null,
    },
    {
      style: "font-weight",
      getAttrs: (v: string) => /^(bold(er)?|[5-9]\d{2,})$/.test(v) && null,
    },
  ],
  toDOM() {
    return ["strong", 0];
  },
};

const EM_MARK = {
  parseDOM: [{ tag: "i" }, { tag: "em" }, { style: "font-style=italic" }],
  toDOM() {
    return ["em", 0];
  },
};

const LINK_MARK = {
  attrs: { href: {} },
  inclusive: false,
  parseDOM: [
    {
      tag: "a[href]",
      getAttrs(dom: HTMLElement) {
        return { href: dom.getAttribute("href") };
      },
    },
  ],
  toDOM(node: { attrs: { href: unknown } }) {
    return [
      "a",
      { href: safeHref(node.attrs.href), rel: "noopener nofollow ugc" },
      0,
    ];
  },
};

/**
 * Extension list for the "plain" schema — no marks, no line breaks. Used for
 * single-line label-like fields (button labels, names, short titles).
 */
const PLAIN_EXTENSIONS = [
  {
    nodeSpec: {
      doc: { content: "text*" },
      text: TEXT_NODE,
    },
  },
];

/**
 * Extension list for the "heading" schema — marks allowed, no line breaks.
 * Used for single-line rich content (heading text, media-card title).
 */
const HEADING_EXTENSIONS = [
  {
    nodeSpec: {
      doc: { content: "text*" },
      text: TEXT_NODE,
    },
    markSpec: {
      strong: STRONG_MARK,
      em: EM_MARK,
      link: LINK_MARK,
    },
  },
];

/**
 * Extension list for the "paragraph" schema — marks and hard breaks allowed.
 * Used for multi-line rich content (paragraph body, callout body, banner
 * content).
 */
const PARAGRAPH_EXTENSIONS = [
  {
    nodeSpec: {
      doc: { content: "inline*" },
      text: TEXT_NODE,
      hard_break: HARD_BREAK_NODE,
    },
    markSpec: {
      strong: STRONG_MARK,
      em: EM_MARK,
      link: LINK_MARK,
    },
  },
];

/**
 * Map of schema variant -> editor configuration. The variant is emitted as
 * a data-attr on the renderer span so the editor controller can resolve the
 * right config when it enters edit mode.
 */
export const SCHEMAS = Object.freeze({
  plain: {
    extensions: PLAIN_EXTENSIONS,
    allowsMarks: false,
    allowsHardBreak: false,
  },
  heading: {
    extensions: HEADING_EXTENSIONS,
    allowsMarks: true,
    allowsHardBreak: false,
  },
  paragraph: {
    extensions: PARAGRAPH_EXTENSIONS,
    allowsMarks: true,
    allowsHardBreak: true,
  },
});
