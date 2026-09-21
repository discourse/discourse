import Controller from "@ember/controller";

export default class DiscourseWorkflowsNodePacksController extends Controller {
  queryParams = [{ openImport: "import" }];
  openImport = null;
}
