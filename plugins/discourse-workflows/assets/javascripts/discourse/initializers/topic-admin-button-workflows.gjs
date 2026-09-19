import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "discourse-workflows-topic-admin-button",

  initialize(container) {
    const site = container.lookup("service:site");
    const workflows = site.topic_admin_button_workflows || [];

    if (!workflows.length) {
      return;
    }

    withPluginApi((api) => {
      workflows.forEach((workflow) => {
        api.addTopicAdminMenuButton((topic) => {
          return {
            icon: workflow.icon,
            translatedLabel: workflow.label,
            className: `workflow-topic-admin-btn-${workflow.workflow_id}`,
            section: {
              id: "discourse-workflows",
              label: "discourse_workflows.title",
            },
            action: () => {
              ajax("/discourse-workflows/trigger-topic-admin-button", {
                type: "POST",
                data: {
                  trigger_node_id: workflow.trigger_node_id,
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
