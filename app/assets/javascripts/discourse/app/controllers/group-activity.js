import Controller from "@ember/controller";
import { service } from "@ember/service";

export default class GroupActivityController extends Controller {
  @service router;

  queryParams = ["category_id"];
}
