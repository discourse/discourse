import { NODE_DIRECT_SETTING_KEYS } from "../../models/workflow-node";

export function workflowFromTemplate(template) {
  return {
    name: template.name,
    nodes: template.nodes.map((n) => {
      const node = {
        id: n.id,
        type: n.type,
        typeVersion: n.typeVersion,
        name: n.name,
        parameters: n.parameters || {},
        credentials: n.credentials || {},
        webhookId: n.webhookId || null,
        position: n.position || null,
      };

      for (const key of NODE_DIRECT_SETTING_KEYS) {
        if (Object.hasOwn(n, key)) {
          node[key] = structuredClone(n[key]);
        }
      }

      return node;
    }),
    connections: template.connections || {},
  };
}
