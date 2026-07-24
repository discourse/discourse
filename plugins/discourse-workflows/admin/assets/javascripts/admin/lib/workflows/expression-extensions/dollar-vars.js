import { i18n } from "discourse-i18n";

const DOLLAR_VAR_DOCS = {
  $input: {
    detail: "object",
    infoKey: "discourse_workflows.expression_docs.vars.input",
  },
  $itemIndex: {
    detail: "number",
    infoKey: "discourse_workflows.expression_docs.vars.item_index",
  },
  $json: {
    detail: "object",
    infoKey: "discourse_workflows.expression_docs.vars.json",
  },
  $trigger: {
    detail: "object",
    infoKey: "discourse_workflows.expression_docs.vars.trigger",
  },
  $site_settings: {
    detail: "object",
    infoKey: "discourse_workflows.expression_docs.vars.site_settings",
  },
  $current_user: {
    detail: "object",
    infoKey: "discourse_workflows.expression_docs.vars.current_user",
  },
  $vars: {
    detail: "object",
    infoKey: "discourse_workflows.expression_docs.vars.workflow_vars",
  },
  $execution: {
    detail: "object",
    infoKey: "discourse_workflows.expression_docs.vars.execution",
  },
};

export function lookupDollarVarDoc(name) {
  const doc = DOLLAR_VAR_DOCS[name];
  if (!doc) {
    return null;
  }
  return { detail: doc.detail, info: i18n(doc.infoKey) };
}

export function buildDollarVars(scope, sections) {
  const groups = [
    {
      names: ["$input", "$json", "$itemIndex", "$trigger"],
      section: sections.recommended,
      boost: (name) => (name === "$json" ? 10 : 5),
    },
    {
      names: ["$site_settings", "$current_user", "$vars", "$execution"],
      section: sections.metadata,
    },
  ];

  const dollarVars = [];
  for (const group of groups) {
    for (const name of group.names) {
      if (name in scope) {
        const docs = lookupDollarVarDoc(name) || {};
        const isObject =
          typeof scope[name] === "object" && scope[name] !== null;
        const entry = {
          label: name,
          apply: isObject ? `${name}.` : name,
          type: "variable",
          detail: docs.detail || "object",
          info: docs.info,
          section: group.section,
        };
        if (group.boost) {
          entry.boost = group.boost(name);
        }
        dollarVars.push(entry);
      }
    }
  }
  dollarVars.push({
    label: "$(",
    apply: "$('",
    type: "function",
    detail: "node reference",
    info: i18n("discourse_workflows.expression_docs.vars.node_ref"),
    section: sections.nodes,
  });
  return dollarVars;
}
