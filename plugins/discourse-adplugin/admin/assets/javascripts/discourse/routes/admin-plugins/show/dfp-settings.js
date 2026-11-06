import { trackedArray } from "@ember/reactive/collections";
import { ajax } from "discourse/lib/ajax";
import Category from "discourse/models/category";
import DiscourseRoute from "discourse/routes/discourse";
import { DFP_CATEGORY_SETTINGS_PATH as PATH } from "../../../../admin/lib/dfp-settings.js";

export default class AdminPluginsShowDfpSettings extends DiscourseRoute {
  async model() {
    const data = await ajax(PATH);

    return {
      settings: trackedArray(
        data.dfp_category_settings.map((setting) => ({
          ...setting,
          category: Category.findById(setting.category_id),
        }))
      ),
    };
  }
}
