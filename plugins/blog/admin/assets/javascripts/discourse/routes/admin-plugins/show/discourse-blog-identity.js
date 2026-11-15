import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class BlogIdentityRoute extends DiscourseRoute {
  async model() {
    const { site_settings } = await ajax("/admin/site_settings.json", {
      data: { plugin: "blog" },
    });
    return {
      ...Object.fromEntries(
        site_settings.map((setting) => [setting.setting, setting.value])
      ),
    };
  }
}
