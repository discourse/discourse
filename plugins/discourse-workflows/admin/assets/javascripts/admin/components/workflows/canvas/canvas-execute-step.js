import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export async function runExecuteStep({ clientId, workflowId, toasts, router }) {
  const result = await ajax(
    "/admin/plugins/discourse-workflows/step-executions.json",
    {
      type: "POST",
      data: { workflow_id: workflowId, node_id: clientId },
    }
  );

  const { workflow_id, id } = result.execution;

  toasts.success({
    data: {
      message: i18n("discourse_workflows.execute_step.triggered"),
      actions: [
        {
          label: i18n("discourse_workflows.execute_step.view_execution"),
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
