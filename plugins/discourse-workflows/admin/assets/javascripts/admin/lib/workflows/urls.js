const WORKFLOWS_PATH = "/admin/plugins/discourse-workflows/workflows";

export function workflowUrl(workflowId) {
  return `${WORKFLOWS_PATH}/${encodeURIComponent(workflowId)}`;
}

export function workflowNodeUrl(workflowId, nodeId) {
  return `${workflowUrl(workflowId)}/nodes/${encodeURIComponent(nodeId)}`;
}
