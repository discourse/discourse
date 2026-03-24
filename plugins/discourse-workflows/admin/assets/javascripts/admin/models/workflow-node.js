export default class WorkflowNode {
  static create(args = {}) {
    return new WorkflowNode(args);
  }

  static serialize(node) {
    return {
      client_id: node.clientId,
      type: node.type,
      type_version: node.type_version,
      name: node.name,
      configuration: node.configuration || {},
      position: node.position || null,
    };
  }

  constructor(args = {}) {
    this.clientId = args.clientId ?? args.id?.toString() ?? crypto.randomUUID();
    this.type = args.type;
    this.type_version = args.type_version ?? "1.0";
    this.name = args.name;
    this.configuration = args.configuration ?? {};
    this.position = args.position ?? null;
  }
}
