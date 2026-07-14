import { i18n } from "discourse-i18n";
import { propertyLabel } from "./property-engine";

const KNOWN_MESSAGES = new Set(["required"]);

export default function formatNodeIssue(issue, nodeType) {
  const label = propertyLabel(nodeType, issue.name);
  const key = KNOWN_MESSAGES.has(issue.message) ? issue.message : "unknown";

  return i18n(`discourse_workflows.node_issues.${key}`, {
    label,
    message: issue.message,
  });
}
