import {
  FORM_TRIGGER_WEBHOOK_ID_KEY,
  NODE_DIRECT_SETTING_KEYS,
} from "../lib/workflows/node-data-shape";

export { NODE_DIRECT_SETTING_KEYS };

function directSettingsFromNodeData(node = {}) {
  const settings = {};

  for (const key of NODE_DIRECT_SETTING_KEYS) {
    if (Object.hasOwn(node, key)) {
      settings[key] = structuredClone(node[key]);
    }
  }

  return settings;
}

function splitConfiguration(configuration = {}, existing = {}) {
  const parameters = structuredClone(configuration || {});
  const directSettings = directSettingsFromNodeData(existing);
  const credentials = Object.hasOwn(parameters, "credentials")
    ? structuredClone(parameters.credentials || {})
    : structuredClone(existing.credentials || {});
  let webhookId = existing.webhookId || null;

  delete parameters.credentials;

  for (const key of NODE_DIRECT_SETTING_KEYS) {
    if (Object.hasOwn(parameters, key)) {
      directSettings[key] = parameters[key];
      delete parameters[key];
    }
  }

  return { parameters, credentials, directSettings, webhookId };
}

function configurationFromNodeData({
  parameters = {},
  credentials = {},
  directSettings = {},
}) {
  const configuration = {
    ...structuredClone(parameters || {}),
    ...structuredClone(directSettings || {}),
  };

  if (credentials && Object.keys(credentials).length > 0) {
    configuration.credentials = structuredClone(credentials);
  }

  return configuration;
}

export default class WorkflowNode {
  static create(args = {}) {
    return new WorkflowNode(args);
  }

  static serialize(node) {
    const split = splitConfiguration(node.configuration, node);

    return {
      id: node.id || node.clientId,
      type: node.type,
      typeVersion: node.typeVersion,
      name: node.name,
      parameters: split.parameters,
      credentials: split.credentials,
      [FORM_TRIGGER_WEBHOOK_ID_KEY]: split.webhookId,
      position: node.position || null,
      ...split.directSettings,
    };
  }

  constructor(args = {}) {
    this.id = args.id?.toString() ?? args.clientId ?? crypto.randomUUID();
    this.clientId = args.clientId ?? this.id;
    this.type = args.type;
    this.typeVersion = args.typeVersion ?? "1.0";
    this.name = args.name;
    this.parameters = args.parameters ?? {};
    this.credentials = args.credentials ?? {};
    this.directSettings = directSettingsFromNodeData(args);
    this.webhookId = args.webhookId ?? null;
    this.configuration =
      args.configuration ??
      configurationFromNodeData({
        parameters: this.parameters,
        credentials: this.credentials,
        directSettings: this.directSettings,
      });
    this.position = args.position ?? null;

    Object.assign(this, this.directSettings);
  }
}
