import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "extend-automation-edit-route",

  initialize() {
    withPluginApi((api) => {
      api.modifyClass("route:admin-plugins/show/automation/edit", {
        pluginId: "discourse-data-explorer",

        queryParams: {
          query_id: {
            refreshModel: false,
          },
        },

        setupController(controller, model) {
          this._super(controller, model);

          const queryId = this.paramsFor(this.routeName).query_id;

          // Pre-fill query_id if provided
          if (queryId && controller.automationForm?.fields) {
            const queryIdField = controller.automationForm.fields.find(
              (f) => f.targetType === "script" && f.name === "query_id"
            );
            if (queryIdField && !queryIdField.metadata?.value) {
              queryIdField.metadata = {
                ...queryIdField.metadata,
                value: parseInt(queryId, 10),
              };
            }

            // Pre-fill execute_at with now for point_in_time trigger
            if (controller.automationForm.trigger === "point_in_time") {
              const executeAtField = controller.automationForm.fields.find(
                (f) => f.targetType === "trigger" && f.name === "execute_at"
              );
              if (executeAtField && !executeAtField.metadata?.value) {
                executeAtField.metadata = {
                  ...executeAtField.metadata,
                  value: new Date().toISOString(),
                };
              }
            }
          }
        },
      });
    });
  },
};
