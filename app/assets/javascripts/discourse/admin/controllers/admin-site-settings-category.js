import Controller from "@ember/controller";
import { alias } from "@ember/object/computed";

export default class AdminSiteSettingsCategoryController extends Controller {
  @alias("model") filteredSiteSettings;
}
