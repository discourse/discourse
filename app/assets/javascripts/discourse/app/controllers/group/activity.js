import Controller from "@ember/controller";
import { service } from "@ember/service";

export default class GroupActivityController extends Controller {
  // eslint-disable-next-line discourse/no-unused-services
  @service siteSettings; // used in the route template

  queryParams = ["category_id"];
}
