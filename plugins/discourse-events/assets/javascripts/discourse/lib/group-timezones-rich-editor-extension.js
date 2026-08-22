import { iconHTML } from "discourse/lib/icon-library";
import { buildBBCodeAttrs } from "discourse/lib/text";
import { i18n } from "discourse-i18n";
import bbcodeBlockInputRule from "./bbcode-block-input-rule";

const DEFAULT_SIZE = "medium";

// the group is already named in the label, and `medium` is the implicit size
function bbcodeAttrs(attrs) {
  return buildBBCodeAttrs({
    ...attrs,
    size: attrs.size === DEFAULT_SIZE ? null : attrs.size,
  });
}

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    group_timezones: {
      attrs: {
        group: { default: null },
        size: { default: DEFAULT_SIZE },
      },
      group: "block",
      // the widget is appended to the element when cooked, so anything the
      // author writes between the tags is kept and rendered alongside it
      content: "block*",
      defining: true,
      isolating: true,
      parseDOM: [
        {
          tag: "div.composer-group-timezones-preview",
          contentElement: "div.composer-group-timezones-preview__body",
          getAttrs(dom) {
            return {
              group: dom.dataset.group || null,
              size: dom.dataset.size || DEFAULT_SIZE,
            };
          },
        },
      ],
      toDOM(node) {
        const wrap = document.createElement("div");
        wrap.classList.add("composer-group-timezones-preview");
        wrap.dataset.size = node.attrs.size ?? DEFAULT_SIZE;
        if (node.attrs.group) {
          wrap.dataset.group = node.attrs.group;
        }

        const header = document.createElement("div");
        header.classList.add("composer-group-timezones-preview__header");
        header.contentEditable = "false";
        header.innerHTML = iconHTML("earth-americas");
        header.appendChild(
          document.createTextNode(
            node.attrs.group
              ? i18n("discourse_calendar.rich_editor.group_timezones_for", {
                  group: node.attrs.group,
                })
              : i18n("discourse_calendar.rich_editor.group_timezones")
          )
        );
        const attrs = bbcodeAttrs({ ...node.attrs, group: null });
        if (attrs) {
          const summary = document.createElement("span");
          summary.classList.add("composer-group-timezones-preview__attrs");
          summary.textContent = attrs;
          header.appendChild(summary);
        }

        wrap.appendChild(header);

        const content = document.createElement("div");
        content.classList.add("composer-group-timezones-preview__body");
        wrap.appendChild(content);

        return { dom: wrap, contentDOM: content };
      },
    },
  },

  parse: {
    div_group_timezones(state, token) {
      if (token.nesting === 1) {
        state.openNode(state.schema.nodes.group_timezones, {
          group: token.attrGet("data-group"),
          size: token.attrGet("data-size") ?? DEFAULT_SIZE,
        });
      } else {
        state.closeNode();
      }

      // claims the token when several extensions parse this type
      return true;
    },
  },

  serializeNode: {
    group_timezones(state, node) {
      const attrs = bbcodeAttrs(node.attrs);
      state.write(`[timezones${attrs ? ` ${attrs}` : ""}]\n`);
      state.renderContent(node);
      state.write("[/timezones]");
      state.closeBlock(node);
    },
  },

  // a group is required, the widget has nothing to show without one
  inputRules: bbcodeBlockInputRule(
    "timezones",
    "group_timezones",
    /^\[timezones\s([^\]]*group=[^\]]*)]$/
  ),
};

export default extension;
