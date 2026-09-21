import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import NodePackImportModal from "discourse/plugins/discourse-workflows/admin/components/workflows/node-pack/import-modal";

export default class DiscourseWorkflowsNodePacksRoute extends DiscourseRoute {
  @service modal;
  @service router;

  queryParams = {
    openImport: { refreshModel: true },
  };

  model(params) {
    return {
      openImport:
        params.openImport === "1" ||
        params.openImport === true ||
        params.import === "1" ||
        params.import === true,
    };
  }

  setupController(controller, model) {
    super.setupController(controller, model);

    if (model.openImport) {
      schedule("afterRender", async () => {
        await this.router.replaceWith({ queryParams: { import: null } });
        schedule("afterRender", () => {
          this.modal.show(NodePackImportModal, { model: {} });
        });
      });
    }
  }
}
