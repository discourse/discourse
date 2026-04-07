import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "discourse-workflows-topic-admin-button",

  initialize(container) {
    const site = container.lookup("service:site");
    const workflows = site.topic_admin_button_workflows || [];

    withPluginApi((api) => {
      workflows.forEach((workflowData) => {
        api.addTopicAdminMenuButton((topic) => {
          const current =
            api.container.lookup("service:site").topic_admin_button_workflows;
          const entry = current?.find(
            (w) => w.trigger_node_id === workflowData.trigger_node_id
          );
          if (!entry) {
            return;
          }

          return {
            icon: entry.icon,
            translatedLabel: entry.label,
            className: `workflow-topic-admin-btn-${entry.workflow_id}`,
            action: () => {
              ajax("/discourse-workflows/trigger-topic-admin-button", {
                type: "POST",
                data: {
                  trigger_node_id: entry.trigger_node_id,
                  topic_id: topic.id,
                },
              }).catch(popupAjaxError);
            },
          };
        });
      });
    });
  },
};
