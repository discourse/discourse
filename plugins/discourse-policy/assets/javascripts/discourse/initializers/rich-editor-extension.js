import { camelize } from "@ember/string";
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
            // Convert data-* attributes to camelCase node attributes
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

        // Set data attributes, converting camelCase back to kebab-case and filtering out empty values
        Object.entries(node.attrs).forEach(([key, value]) => {
          if (value && value.trim() !== "" && value !== '""') {
            const dataKey = key.replace(/([A-Z])/g, "-$1").toLowerCase();
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

      // Set data attributes
      Object.entries(node.attrs).forEach(([key, value]) => {
        if (value && value.trim() !== "" && value !== '""') {
          const dataKey = key.replace(/([A-Z])/g, "-$1").toLowerCase();
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

          // Update data attributes if they changed
          Object.entries(updatedNode.attrs).forEach(([key, value]) => {
            const dataKey = key.replace(/([A-Z])/g, "-$1").toLowerCase();
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
          // Convert camelCase back to kebab-case for BBCode
          const kebabKey = key.replace(/([A-Z])/g, "-$1").toLowerCase();
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
