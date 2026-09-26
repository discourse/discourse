import Controller from "@ember/controller";
import { service } from "discourse/lib/service";
import SiteSettingsService from "discourse/services/site-settings";

export default class GroupActivityController extends Controller {
  // eslint-disable-next-line discourse/no-unused-services
  @service(() => SiteSettingsService) siteSettings; // used in the route template

  queryParams = ["category_id"];
}
