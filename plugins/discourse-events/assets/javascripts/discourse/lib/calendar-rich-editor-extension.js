import { iconHTML } from "discourse/lib/icon-library";
import { buildBBCodeAttrs } from "discourse/lib/text";
import { i18n } from "discourse-i18n";
import bbcodeBlockInputRule from "./bbcode-block-input-rule";

const DATA_ATTRIBUTES = {
  type: "data-calendar-type",
  defaultView: "data-calendar-default-view",
  defaultTimezone: "data-calendar-default-timezone",
  weekends: "data-weekends",
  showAddToCalendar: "data-calendar-show-add-to-calendar",
  fullDay: "data-calendar-full-day",
  hiddenDays: "data-hidden-days",
};

function extractAttrs(getValue) {
  const attrs = {};
  for (const [attr, dataAttribute] of Object.entries(DATA_ATTRIBUTES)) {
    const value = getValue(dataAttribute);
    // the markdown rule pushes booleans, the DOM gives strings
    if (value != null) {
      attrs[attr] = String(value);
    }
  }
  return attrs;
}

// `dynamic` is the implicit type, so it is left out of the tag
function bbcodeAttrs(attrs) {
  return buildBBCodeAttrs({
    ...attrs,
    type: attrs.type === "dynamic" ? null : attrs.type,
  });
}

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    calendar: {
      attrs: {
        type: { default: "dynamic" },
        defaultView: { default: null },
        defaultTimezone: { default: null },
        weekends: { default: null },
        showAddToCalendar: { default: null },
        fullDay: { default: null },
        hiddenDays: { default: null },
      },
      group: "block",
      // the cooked block keeps whatever the author wrote, so the node has to
      // accept it all - the decorator only renders events from the first
      // paragraph, but narrowing this would delete the rest of the source
      content: "block*",
      defining: true,
      isolating: true,
      parseDOM: [
        {
          tag: "div.composer-calendar-preview",
          contentElement: "div.composer-calendar-preview__body",
          getAttrs(dom) {
            const calendar = dom.querySelector(
              "div.composer-calendar-preview__body"
            );
            return extractAttrs((name) => calendar?.getAttribute(name));
          },
        },
      ],
      toDOM(node) {
        const wrap = document.createElement("div");
        wrap.classList.add("composer-calendar-preview");

        const header = document.createElement("div");
        header.classList.add("composer-calendar-preview__header");
        header.contentEditable = "false";
        header.innerHTML = iconHTML("calendar-days");
        header.appendChild(
          document.createTextNode(
            i18n("discourse_calendar.rich_editor.calendar")
          )
        );
        const attrs = bbcodeAttrs(node.attrs);
        if (attrs) {
          const summary = document.createElement("span");
          summary.classList.add("composer-calendar-preview__attrs");
          summary.textContent = attrs;
          header.appendChild(summary);
        }

        wrap.appendChild(header);

        const content = document.createElement("div");
        content.classList.add("composer-calendar-preview__body");
        for (const [attr, dataAttribute] of Object.entries(DATA_ATTRIBUTES)) {
          if (node.attrs[attr] !== null) {
            content.setAttribute(dataAttribute, node.attrs[attr]);
          }
        }
        wrap.appendChild(content);

        return { dom: wrap, contentDOM: content };
      },
    },
  },

  parse: {
    div_calendar_wrap() {
      return true;
    },
    div_calendar(state, token) {
      if (token.nesting === 1) {
        state.openNode(
          state.schema.nodes.calendar,
          extractAttrs((name) => token.attrGet(name))
        );
      } else {
        state.closeNode();
      }
      return true;
    },
  },

  serializeNode: {
    calendar(state, node) {
      const attrs = bbcodeAttrs(node.attrs);
      state.write(`[calendar${attrs ? ` ${attrs}` : ""}]\n`);

      if (node.content.size > 0) {
        state.renderContent(node);
      }

      state.write("[/calendar]");
      state.closeBlock(node);
    },
  },

  inputRules: bbcodeBlockInputRule("calendar", "calendar"),
};

export default extension;
