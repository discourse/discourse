import { camelize } from "@ember/string";
import { camelCaseToDash } from "discourse/lib/case-converter";
import { withPluginApi } from "discourse/lib/plugin-api";

const POLICY_ATTRIBUTES = {
  group: { default: null },
  groups: { default: null },
  version: { default: "1" },
  accept: { default: null },
  revoke: { default: null },
  reminder: { default: null },
  renewStart: { default: null },
  private: { default: null },
};

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    policy: {
      attrs: POLICY_ATTRIBUTES,
      group: "block",
      content: "block*",
      createGapCursor: true,
      parseDOM: [
        {
          tag: "div.policy",
          getAttrs: (dom) => {
            const attrs = {};
            Object.entries(dom.dataset).forEach(([key, value]) => {
              if (value && value.trim() !== "" && value !== '""') {
                attrs[camelize(key)] = value;
              }
            });
            return attrs;
          },
        },
      ],
      toDOM(node) {
        const attrs = { class: "policy" };

        Object.entries(node.attrs).forEach(([key, value]) => {
          if (value && value.trim() !== "" && value !== '""') {
            const dataKey = camelCaseToDash(key);
            attrs[`data-${dataKey}`] = value;
          }
        });

        return ["div", attrs, 0];
      },
    },
  },

  nodeViews: {
    policy: () => (node) => {
      const dom = document.createElement("div");
      dom.classList.add("policy");

      Object.entries(node.attrs).forEach(([key, value]) => {
        if (value && value.trim() !== "" && value !== '""') {
          const dataKey = camelCaseToDash(key);
          dom.setAttribute(`data-${dataKey}`, value);
        }
      });

      // Create policy header
      const header = document.createElement("div");
      header.classList.add("policy-header");
      header.textContent = "Policy";
      dom.appendChild(header);

      // Create content wrapper
      const contentDOM = document.createElement("div");
      contentDOM.classList.add("policy-body");
      dom.appendChild(contentDOM);

      return {
        dom,
        contentDOM,
        update: (updatedNode) => {
          if (updatedNode.type !== node.type) {
            return false;
          }

          Object.entries(updatedNode.attrs).forEach(([key, value]) => {
            const dataKey = camelCaseToDash(key);
            if (value && value.trim() !== "" && value !== '""') {
              dom.setAttribute(`data-${dataKey}`, value);
            } else {
              dom.removeAttribute(`data-${dataKey}`);
            }
          });

          return true;
        },
      };
    },
  },

  parse: {
    wrap_bbcode(state, token) {
      if (token.tag === "div") {
        if (token.nesting === -1 && state.top().type.name === "policy") {
          state.closeNode();
          return true;
        }

        if (token.nesting === 1 && token.attrGet("class") === "policy") {
          const attrs = {};
          token.attrs?.forEach(([key, value]) => {
            if (key.startsWith("data-")) {
              const attrName = camelize(key.slice(5));
              if (value && value.trim() !== "" && value !== '""') {
                attrs[attrName] = value;
              }
            }
          });

          state.openNode(state.schema.nodes.policy, attrs);
          return true;
        }
      }

      return false;
    },
  },

  serializeNode: {
    policy(state, node) {
      state.write("[policy");

      Object.entries(node.attrs).forEach(([key, value]) => {
        if (value && value.trim() !== "" && value !== '""') {
          const kebabKey = camelCaseToDash(key);
          state.write(` ${kebabKey}="${value}"`);
        }
      });

      state.write("]\n");

      if (node.content.size > 0) {
        state.renderContent(node);
      }

      state.write("[/policy]\n\n");
    },
  },
};

export default {
  name: "rich-editor-policy-extension",
  initialize() {
    withPluginApi((api) => {
      api.registerRichEditorExtension(extension);
    });
  },
};
