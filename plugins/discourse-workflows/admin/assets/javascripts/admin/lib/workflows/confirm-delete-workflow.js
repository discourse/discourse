import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import InUseDialog from "../../components/workflows/in-use-dialog.gjs";

export default async function confirmDeleteWorkflow(
  dialog,
  workflow,
  { onDeleted }
) {
  await dialog.deleteConfirm({
    message: i18n("discourse_workflows.delete_confirm", {
      name: workflow.name,
    }),
    didConfirm: async () => {
      try {
        await workflow.destroyRecord();
        onDeleted(workflow);
      } catch (e) {
        const body = e.jqXHR?.responseJSON;
        if (body?.type === "workflow_called_by_other_workflows") {
          dialog.alert({
            title: i18n("discourse_workflows.in_use_title"),
            bodyComponent: InUseDialog,
            bodyComponentModel: {
              description: i18n("discourse_workflows.in_use_description"),
              workflows: body.referencing_workflows,
              close: () => dialog.cancel(),
            },
          });
        } else {
          popupAjaxError(e);
        }
      }
    },
  });
}
