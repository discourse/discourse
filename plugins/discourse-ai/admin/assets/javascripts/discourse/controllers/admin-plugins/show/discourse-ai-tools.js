import Controller from "@ember/controller";

/**
 * Declares the query param that opens the new tool menu on a preset category,
 * which `AiToolListEditor` reads from the current route.
 */
export default class AdminPluginsShowDiscourseAiToolsController extends Controller {
  queryParams = ["presetCategory"];
  presetCategory = null;
}
