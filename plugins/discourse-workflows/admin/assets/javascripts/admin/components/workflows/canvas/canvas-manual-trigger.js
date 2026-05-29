import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { getAbsoluteURL } from "discourse/lib/get-url";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

async function createFormTestSession(workflowId, triggerNodeId) {
  return await ajax(
    `/admin/plugins/discourse-workflows/workflows/${workflowId}/form-test-sessions.json`,
    {
      type: "POST",
      data: { trigger_node_id: triggerNodeId },
    }
  );
}

export async function runManualTrigger({
  node,
  clientId,
  workflowId,
  toasts,
  router,
  session,
}) {
  if (node?.type === "trigger:form") {
    const result = await createFormTestSession(workflowId, clientId);
    window.open(getAbsoluteURL(result.test_url), "_blank");
    return;
  }

  if (node?.type === "trigger:webhook" && node.configuration?.path) {
    const listener = await session.startWebhookTestListener(clientId);
    const testUrl = getAbsoluteURL(listener.testUrl);
    toasts.success({
      data: {
        message: i18n("discourse_workflows.manual_trigger.listening"),
        actions: [
          {
            label: i18n("discourse_workflows.webhook.copy_test_url"),
            class: "btn-primary btn-small",
            action: async ({ close }) => {
              await clipboardCopy(testUrl);
              close();
            },
          },
        ],
      },
    });
    return;
  }

  let result;
  try {
    result = await ajax(`/admin/plugins/discourse-workflows/executions.json`, {
      type: "POST",
      data: { workflow_id: workflowId, trigger_node_id: clientId },
    });
  } catch (error) {
    // Service refuses to run when the trigger has no pinned sample data and no
    // synthesised manual payload (e.g. event-based triggers like post_created).
    if (error?.jqXHR?.status === 422) {
      toasts.error({
        data: {
          message: i18n("discourse_workflows.manual_trigger.needs_pin_data"),
        },
      });
      return;
    }
    popupAjaxError(error);
    return;
  }

  const { workflow_id, id } = result.execution;

  toasts.success({
    data: {
      message: i18n("discourse_workflows.manual_trigger.triggered"),
      actions: [
        {
          label: i18n("discourse_workflows.manual_trigger.view_execution"),
          class: "btn-primary btn-small",
          action: ({ close }) => {
            close();
            router.transitionTo(
              "adminPlugins.show.discourse-workflows.show.executions.show",
              workflow_id,
              id
            );
          },
        },
      ],
    },
  });
}
