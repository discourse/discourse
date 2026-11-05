import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";

export default class ReportIllegalContentController extends Controller {
  @tracked content_url = "";

  queryParams = ["content_url"];
}
