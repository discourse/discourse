import { camelize } from "@ember/string";
import { camelCaseToDash } from "discourse/lib/case-converter";
import { iconHTML } from "discourse/lib/icon-library";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import PolicyBuilder from "../components/modal/policy-builder";

const POLICY_ATTRIBUTES = {
  group: { default: null },
  groups: { default: null },
  version: { default: "1" },
  accept: { default: null },
  revoke: { default: null },
  reminder: { default: null },
  renew: { default: null },
  renewStart: { default: null },
  addUsersToGroup: { default: null },
  private: { default: null },
};

const DISPLAYED_POLICY_ATTRIBUTES = [
  "groups",
  "group",
  "version",
  "renew",
  "renewStart",
  "reminder",
  "accept",
  "revoke",
  "addUsersToGroup",
  "private",
];

function hasAttributeValue(value) {
  return (
    value !== null &&
    value !== undefined &&
    String(value).trim() !== "" &&
    String(value) !== '\"\"'
  );
}

function policyAttrsToFormPolicy(attrs) {
  const policy = {};

  Object.entries(attrs).forEach(([key, value]) => {
    if (!hasAttributeValue(value)) {
      return;
    }

    policy[key] = key === "private" ? value === "true" : value;
  });

  if (!policy.groups && policy.group) {
    policy.groups = policy.group;
    delete policy.group;
  }

  return policy;
}

function formPolicyToPolicyAttrs(policy) {
  const attrs = {};

  Object.keys(POLICY_ATTRIBUTES).forEach((key) => {
    attrs[key] = null;
  });

  Object.entries(policy).forEach(([key, value]) => {
    if (key === "private") {
      attrs.private = value === true || value === "true" ? "true" : null;
      return;
    }

    attrs[camelize(key)] = hasAttributeValue(value) ? String(value) : null;
  });

  return attrs;
}

const createPolicyNodeView =
  ({ getContext, pmState: { NodeSelection } }) =>
  (node, view, getPos) =>
    new PolicyNodeView({ node, view, getPos, getContext, NodeSelection });

class PolicyNodeView {
  node;
  view;
  getPos;
  getContext;
  NodeSelection;
  dom;
  details;
  contentDOM;
  editButton;

  openEditModal = (event) => {
    event.preventDefault();
    event.stopPropagation();

    const { modal } = this.getContext();
    modal.show(PolicyBuilder, {
      model: {
        policy: policyAttrsToFormPolicy(this.node.attrs),
        onApply: (policy) => this.#applyEdit(policy),
      },
    });
  };

  constructor({ node, view, getPos, getContext, NodeSelection }) {
    this.node = node;
    this.view = view;
    this.getPos = getPos;
    this.getContext = getContext;
    this.NodeSelection = NodeSelection;

    this.dom = document.createElement("div");
    this.dom.classList.add("policy");

    this.#syncAttributes();

    const header = document.createElement("div");
    header.classList.add("policy-header");
    header.setAttribute("contenteditable", "false");

    const title = document.createElement("span");
    title.textContent = i18n("discourse_policy.title");
    header.appendChild(title);

    this.editButton = document.createElement("button");
    this.editButton.type = "button";
    this.editButton.classList.add("btn-flat", "policy-node-edit-button");
    this.editButton.setAttribute("contenteditable", "false");
    this.editButton.setAttribute(
      "title",
      i18n("discourse_policy.builder.edit")
    );
    this.editButton.setAttribute(
      "aria-label",
      i18n("discourse_policy.builder.edit")
    );
    this.editButton.innerHTML = iconHTML("pencil");
    this.editButton.addEventListener("click", this.openEditModal);
    header.appendChild(this.editButton);

    this.dom.appendChild(header);

    this.details = document.createElement("dl");
    this.details.classList.add("policy-attrs");
    this.details.setAttribute("contenteditable", "false");
    this.dom.appendChild(this.details);

    this.contentDOM = document.createElement("div");
    this.contentDOM.classList.add("policy-body");
    this.dom.appendChild(this.contentDOM);

    this.#syncDetails();
  }

  update(node) {
    if (node.type !== this.node.type) {
      return false;
    }

    this.node = node;
    this.#syncAttributes();
    this.#syncDetails();

    return true;
  }

  stopEvent(event) {
    return event.target instanceof Node
      ? this.editButton.contains(event.target)
      : false;
  }

  ignoreMutation(mutation) {
    return !this.contentDOM.contains(mutation.target);
  }

  destroy() {
    this.editButton.removeEventListener("click", this.openEditModal);
  }

  #syncAttributes() {
    Object.keys(POLICY_ATTRIBUTES).forEach((key) => {
      this.dom.removeAttribute(`data-${camelCaseToDash(key)}`);
    });

    Object.entries(this.node.attrs).forEach(([key, value]) => {
      if (hasAttributeValue(value)) {
        const dataKey = camelCaseToDash(key);
        this.dom.setAttribute(`data-${dataKey}`, value);
      }
    });
  }

  #syncDetails() {
    this.details.replaceChildren();

    DISPLAYED_POLICY_ATTRIBUTES.forEach((key) => {
      const value = this.node.attrs[key];

      if (!hasAttributeValue(value)) {
        return;
      }

      const name = document.createElement("dt");
      const labelKey = key === "group" ? "groups" : camelCaseToDash(key);
      name.textContent = i18n(`discourse_policy.builder.${labelKey}.label`);

      const definition = document.createElement("dd");
      definition.textContent = value;

      this.details.append(name, definition);
    });
  }

  #applyEdit(policy) {
    const pos = this.getPos();
    const attrs = formPolicyToPolicyAttrs(policy);
    const tr = this.view.state.tr.setNodeMarkup(pos, null, attrs);
    tr.setSelection(this.NodeSelection.create(tr.doc, pos));
    this.view.dispatch(tr);
  }
}

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
              if (hasAttributeValue(value)) {
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
          if (hasAttributeValue(value)) {
            const dataKey = camelCaseToDash(key);
            attrs[`data-${dataKey}`] = value;
          }
        });

        return ["div", attrs, 0];
      },
    },
  },

  nodeViews: {
    policy: createPolicyNodeView,
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
              if (hasAttributeValue(value)) {
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
        if (hasAttributeValue(value)) {
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
