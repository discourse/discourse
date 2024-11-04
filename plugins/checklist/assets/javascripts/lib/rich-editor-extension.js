export default {
  // TODO(renato): make the checkbox clickable
  // TODO(renato): auto-continue checkbox list on ENTER
  // TODO(renato): apply .has-checkbox style to the <li> to avoid :has
  nodeSpec: {
    check: {
      attrs: { checked: { default: false } },
      inline: true,
      group: "inline",
      draggable: true,
      selectable: false,
      toDOM(node) {
        return [
          "span",
          {
            class: node.attrs.checked
              ? "chcklst-box checked fa fa-square-check-o fa-fw"
              : "chcklst-box fa fa-square-o fa-fw",
          },
        ];
      },
      parseDOM: [
        {
          tag: "span.chcklst-box",
          getAttrs: (dom) => {
            return { checked: hasCheckedClass(dom.className) };
          },
        },
      ],
    },
  },

  inputRules: [
    {
      match: /(?<=^|\s)\[(x? ?)]$/,
      handler: (state, match, start, end) =>
        state.tr.replaceWith(
          start,
          end,
          state.schema.nodes.check.create({ checked: match[1] === "x" })
        ),
      options: { undoable: false },
    },
  ],

  parse: {
    check_open: {
      node: "check",
      getAttrs: (token) => ({
        checked: hasCheckedClass(token.attrGet("class")),
      }),
    },
    check_close: { noCloseToken: true, ignore: true },
  },

  serializeNode: {
    check: (state, node) => {
      state.write(node.attrs.checked ? "[x]" : "[ ]");
    },
  },
};

const CHECKED_REGEX = /\bchecked\b/;

function hasCheckedClass(className) {
  return CHECKED_REGEX.test(className);
}
