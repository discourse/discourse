import { i18n } from "discourse-i18n";
import WrapNodeView from "../components/wrap-node-view";
import GlimmerNodeView from "../lib/glimmer-node-view";
import { parseAttributesString, serializeAttributes } from "../lib/wrap-utils";

// Helper functions to bridge between DOM/token data and wrap-utils format
function extractDataset(dom) {
  const data = { ...dom.dataset };
  // Don't include the structural CSS class as a data attribute
  delete data.class;
  return data;
}

function buildDataAttributes(data) {
  const attrs = {};
  if (!data) {
    return attrs;
  }
  for (const [key, value] of Object.entries(data)) {
    if (value == null || value === "") {
      continue;
    }
    attrs[`data-${key}`] = value;
  }
  return attrs;
}

function extractTokenDataAttributes(token) {
  const data = {};
  if (!token?.attrs) {
    return data;
  }
  for (const [name, value] of token.attrs) {
    if (name.startsWith("data-")) {
      // Data attributes: remove data- prefix
      const key = name.slice(5);
      data[key] = value;
    } else if (name === "class" && value === "d-wrap") {
      // Skip structural CSS class from markdown-it
      continue;
    } else {
      // All other attributes (including wrap) become data attributes
      data[name] = value;
    }
  }
  return data;
}

// Convert data object to wrap attribute string format
function serializeWrapAttributes(data) {
  if (!data || Object.keys(data).length === 0) {
    return "";
  }

  // Convert data object keys to wrap format (extract wrap name if present)
  const wrapName = data.wrap || "";
  const attributes = Object.entries(data)
    .filter(([key]) => key !== "wrap")
    .map(([key, value]) => ({ key, value }));

  const serialized = serializeAttributes(wrapName, attributes);

  // If we have attributes but no wrap name, we need to add a space at the beginning
  if (!wrapName && attributes.length > 0 && serialized) {
    return ` ${serialized}`;
  }

  return serialized;
}

const createWrapNodeView =
  ({ getContext }) =>
  (node, view, getPos) =>
    new GlimmerNodeView({
      node,
      view,
      getPos,
      getContext,
      component: WrapNodeView,
      name: "wrap",
      hasContent: true,
    });

/** @type {import("discourse/lib/composer/rich-editor-extensions").RichEditorExtension} */
const extension = {
  nodeViews: {
    wrap_block: createWrapNodeView,
    wrap_inline: createWrapNodeView,
  },

  commands: ({ schema }) => ({
    insertWrap:
      (attributes = {}) =>
      (state, dispatch, view) => {
        const { selection } = state;
        const { empty, $from, $to } = selection;

        for (let depth = $from.depth; depth >= 0; depth--) {
          const node = $from.node(depth);
          if (
            node.type.name === "wrap_block" ||
            node.type.name === "wrap_inline"
          ) {
            // TODO shouldn't it unwrap?
            return false;
          }
        }

        const attrs = { data: attributes };
        const tr = state.tr;

        if (empty) {
          // Empty selection: choose block vs inline based on cursor position
          const isBlockWrap = view?.endOfTextblock?.("backward");
          const wrapType = isBlockWrap
            ? schema.nodes.wrap_block
            : schema.nodes.wrap_inline;

          if (!wrapType) {
            return false;
          }

          const wrap = isBlockWrap
            ? wrapType.create(attrs, schema.nodes.paragraph.create())
            : wrapType.create(attrs);

          tr.replaceSelectionWith(wrap);

          if (isBlockWrap) {
            tr.setSelection(
              selection.constructor.create(tr.doc, $from.pos + 2)
            );
          }
        } else {
          // Non-empty selection: check if it's a full block selection
          const isBlockSelection =
            $from.parent === $to.parent &&
            $from.parentOffset === 0 &&
            $to.parentOffset === $from.parent.content.size &&
            $from.parent.isBlock &&
            $from.depth > 0;

          if (isBlockSelection) {
            const wrapType = schema.nodes.wrap_block;
            if (!wrapType) {
              return false;
            }

            const range = $from.blockRange($to);
            if (!range) {
              return false;
            }

            tr.wrap(range, [{ type: wrapType, attrs }]);
          } else {
            const wrapType = schema.nodes.wrap_inline;
            if (!wrapType) {
              return false;
            }

            const content = state.doc.slice(selection.from, selection.to);
            const wrap = wrapType.create(attrs, content.content);
            tr.replaceWith(selection.from, selection.to, wrap);
          }
        }

        dispatch?.(tr);
        return true;
      },
  }),
  nodeSpec: {
    wrap_block: {
      content: "block+",
      group: "block",
      defining: true,
      createGapCursor: true,
      attrs: {
        data: { default: {} },
      },
      parseDOM: [
        {
          tag: "div.d-wrap",
          getAttrs(dom) {
            return { data: extractDataset(dom) };
          },
        },
      ],
      toDOM(node) {
        const attrs = {
          class: "d-wrap",
          ...buildDataAttributes(node.attrs.data),
        };
        return ["div", attrs, 0];
      },
    },

    wrap_inline: {
      inline: true,
      group: "inline",
      content: "inline*",
      defining: true,
      attrs: {
        data: { default: {} },
      },
      parseDOM: [
        {
          tag: "span.d-wrap",
          getAttrs(dom) {
            return { data: extractDataset(dom) };
          },
        },
      ],
      toDOM(node) {
        const attrs = {
          class: "d-wrap",
          contenteditable: "false",
          ...buildDataAttributes(node.attrs.data),
        };
        return ["span", attrs, 0];
      },
    },
  },

  parse: {
    wrap_open(state, token) {
      const isInline = token.tag === "span";
      const nodeType = isInline
        ? state.schema.nodes.wrap_inline
        : state.schema.nodes.wrap_block;

      if (!nodeType) {
        return;
      }

      const data = extractTokenDataAttributes(token);
      state.openNode(nodeType, { data });
      return true;
    },

    wrap_close(state) {
      const top = state.top();
      if (!top) {
        return;
      }
      if (top.type.name === "wrap_block" || top.type.name === "wrap_inline") {
        state.closeNode();
        return true;
      }
    },
  },

  serializeNode: {
    wrap_block(state, node) {
      const attrs = serializeWrapAttributes(node.attrs.data);
      state.write(`[wrap${attrs}]\n`);
      state.renderContent(node);
      state.write("[/wrap]\n\n");
    },

    wrap_inline(state, node) {
      const attrs = serializeWrapAttributes(node.attrs.data);
      state.write(`[wrap${attrs}]`);
      state.renderInline(node);
      state.write("[/wrap]");
    },
  },

  inputRules: ({ pmState: { TextSelection } }) => ({
    match: /\[wrap([^\]]*)]$/,
    handler: (state, match, start, end) => {
      const { schema } = state;
      const isAtStart = state.doc.resolve(start).parentOffset === 0;

      // Parse attributes from the match using the utility function
      const attributeString = match[1] || "";
      const attributes = parseAttributesString(attributeString);

      const tr = state.tr;

      if (isAtStart) {
        // Block wrap: create with paragraph containing placeholder text
        const textNode = schema.text(i18n("composer.wrap_text"));
        const wrapNode = schema.nodes.wrap_block.createAndFill(
          { data: attributes },
          schema.nodes.paragraph.createAndFill(null, textNode)
        );

        tr.replaceWith(start - 1, end, wrapNode);

        // Position cursor with text selected
        tr.setSelection(
          TextSelection.create(tr.doc, start + 1, start + 1 + textNode.nodeSize)
        );
      } else {
        // Inline wrap: create with placeholder text
        const textNode = schema.text(i18n("composer.wrap_text"));
        const wrapNode = schema.nodes.wrap_inline.createAndFill(
          { data: attributes },
          textNode
        );

        tr.replaceWith(start, end, wrapNode);

        // Position cursor with text selected
        tr.setSelection(
          TextSelection.create(tr.doc, start + 1, start + 1 + textNode.nodeSize)
        );
      }

      return tr;
    },
  }),
};

export default extension;
