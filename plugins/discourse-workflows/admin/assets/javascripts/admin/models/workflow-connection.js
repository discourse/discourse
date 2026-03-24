export default class WorkflowConnection {
  static create(args = {}) {
    return new WorkflowConnection(args);
  }

  static serialize(connection) {
    return {
      source_client_id: connection.sourceClientId,
      target_client_id: connection.targetClientId,
      source_output: connection.sourceOutput,
    };
  }

  constructor(args = {}) {
    this.sourceClientId =
      args.sourceClientId ?? args.source_node_id?.toString();
    this.targetClientId =
      args.targetClientId ?? args.target_node_id?.toString();
    this.sourceOutput = args.sourceOutput ?? args.source_output ?? "main";
  }
}
