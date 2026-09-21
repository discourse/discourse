import { i18n } from "discourse-i18n";

export function nodePackDisableConfirmation() {
  return i18n("discourse_workflows.node_packs.disable_confirm");
}

export function nodePackRemovalMessages(activeExecutions = 0) {
  const messages = [
    i18n("discourse_workflows.node_packs.credentials_retained"),
  ];
  if (activeExecutions > 0) {
    messages.unshift(
      i18n("discourse_workflows.node_packs.active_executions_blocking", {
        count: activeExecutions,
      })
    );
  }
  return messages;
}

export function nodePackLifecycleUpdate(nodePack, property) {
  return { [property]: !nodePack[property] };
}
