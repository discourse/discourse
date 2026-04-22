import { ajax } from "discourse/lib/ajax";
import { getAbsoluteURL } from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

export async function runManualTrigger({ node, clientId, toasts, router }) {
  if (node?.type === "trigger:form" && node.configuration?.uuid) {
    window.open(
      getAbsoluteURL(`/workflows/form/${node.configuration.uuid}`),
      "_blank"
    );
    return;
  }

  if (node?.type === "trigger:webhook" && node.configuration?.path) {
    window.open(
      getAbsoluteURL(`/workflows/webhooks/${node.configuration.path}`),
      "_blank"
    );
    return;
  }

  const result = await ajax(
    `/admin/plugins/discourse-workflows/executions.json`,
    {
      type: "POST",
      data: { trigger_node_id: clientId },
    }
  );
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
