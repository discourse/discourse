import curryComponent from "ember-curry-component";
import { withPluginApi } from "discourse/lib/plugin-api";
import BoardsAccessControlField from "discourse/plugins/boards/discourse/components/boards-access-control-field";
import {
  boardPermissionOptions,
  buildDefaultBoardAcl,
} from "discourse/plugins/boards/discourse/lib/boards-access-control";

export default {
  name: "boards-workflows",

  initialize(container, app) {
    const site = container.lookup("service:site");
    const siteSettings = container.lookup("service:site-settings");

    if (!siteSettings.enable_discourse_workflows) {
      return;
    }

    const fieldArgs = {
      fieldComponent: BoardsAccessControlField,
      transformPermissionOptions: boardPermissionOptions,
    };

    withPluginApi((api) => {
      api.registerValueTransformer("workflow-node-defaults", ({ value }) => ({
        ...value,
        "action:create_board": () => ({
          acl: buildDefaultBoardAcl(site, siteSettings),
        }),
      }));

      api.registerValueTransformer(
        "workflow-field-control",
        ({ value, context }) => {
          if (
            context.node?.type !== "action:create_board" ||
            context.fieldName !== "acl" ||
            context.control !== "access_control"
          ) {
            return value;
          }

          return {
            ...value,
            renderer: curryComponent(value.renderer, fieldArgs, app),
          };
        }
      );
    });
  },
};
