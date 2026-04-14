export const WORKFLOW_VARIABLE_MIME = "application/x-workflow-variable";

export function resolveVariableId(variable, itemPrefix = "$json") {
  return variable.id.startsWith("$")
    ? variable.id
    : `${itemPrefix}.${variable.id}`;
}

// Matches paths like $('Node Name').rest or $("Node Name").rest
const NODE_REF_RE = /^\$\((['"])(.*?)\1\)/;

export function walkScope(scope, path) {
  if (!path) {
    return undefined;
  }

  const nodeRef = NODE_REF_RE.exec(path);
  if (nodeRef) {
    const nodeName = nodeRef[2];
    const rest = path.slice(nodeRef[0].length);
    const parts = rest ? rest.slice(1).split(".") : []; // skip leading "."
    let target;
    try {
      target = scope.$(nodeName);
    } catch {
      return undefined;
    }
    for (const part of parts) {
      if (target == null) {
        return undefined;
      }
      target = target[part];
    }
    return target;
  }

  const parts = path.split(".");
  let target = scope[parts[0]];
  for (let i = 1; i < parts.length; i++) {
    if (target == null) {
      return undefined;
    }
    target = target[parts[i]];
  }
  return target;
}

const TYPE_EXEMPLARS = {
  string: "",
  integer: 0,
  number: 0,
  boolean: false,
  array: [],
  object: {},
};

function cleanObject(obj) {
  const clean = Object.create(null);
  for (const [key, value] of Object.entries(obj)) {
    clean[key] = value;
  }
  return clean;
}

const EMPTY_NODE_OUTPUT = cleanObject({
  item: cleanObject({ json: Object.create(null) }),
});

function buildScopeFromFields(fields) {
  if (!fields?.length) {
    return Object.create(null);
  }

  const obj = Object.create(null);
  for (const field of fields) {
    if (field.children?.length) {
      obj[field.key] = buildScopeFromFields(field.children);
    } else {
      obj[field.key] = TYPE_EXEMPLARS[field.type] ?? TYPE_EXEMPLARS.string;
    }
  }
  return obj;
}

function buildSiteSettingsScope(siteSettings) {
  if (!siteSettings) {
    return Object.create(null);
  }

  const scope = Object.create(null);
  for (const key of Object.keys(siteSettings)) {
    if (key.startsWith("_") || key.startsWith("theme")) {
      continue;
    }

    const value = siteSettings[key];
    const type = typeof value;

    if (type === "function" || type === "symbol") {
      continue;
    }

    scope[key] = value;
  }
  return scope;
}

function buildVarsScope(workflowVars) {
  const scope = Object.create(null);
  if (workflowVars?.length) {
    for (const v of workflowVars) {
      scope[v.key] = v.value ?? "";
    }
  }
  return scope;
}

function buildExecutionScope(nodes) {
  const scope = cleanObject({
    id: 0,
    workflow_id: 0,
    workflow_name: "",
  });

  const hasWebhookWait = (nodes || []).some(
    (n) => n.type === "flow:wait" && n.configuration?.resume === "webhook"
  );

  if (hasWebhookWait) {
    scope.resume_url = "";
  }

  return scope;
}

export function buildScope({
  inputFields = [],
  ancestorNodes = [],
  siteSettings,
  workflowVars,
  nodes,
}) {
  const $json = buildScopeFromFields(inputFields);

  const nodeOutputs = Object.create(null);
  for (const ancestor of ancestorNodes) {
    const json = buildScopeFromFields(ancestor.fields);
    nodeOutputs[ancestor.node.name] = cleanObject({
      item: cleanObject({ json }),
    });
  }

  return cleanObject({
    $json,
    trigger: $json,
    $site_settings: buildSiteSettingsScope(siteSettings),
    $current_user: cleanObject({ id: 0, username: "" }),
    $vars: buildVarsScope(workflowVars),
    $execution: buildExecutionScope(nodes),
    $: (name) => nodeOutputs[name] || EMPTY_NODE_OUTPUT,
    JSON,
    Math,
    Object,
    Array,
    String,
    Number,
    Date,
    parseInt,
    parseFloat,
    encodeURIComponent,
    decodeURIComponent,
    isNaN,
    isFinite,
  });
}
