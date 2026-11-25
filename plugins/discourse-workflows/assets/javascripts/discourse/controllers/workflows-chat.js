import Controller from "@ember/controller";

export default class WorkflowsChatController extends Controller {
  queryParams = ["draft"];

  draft = false;
}
