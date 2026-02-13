import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class TagEditRoute extends DiscourseRoute {
  @service router;
  @service siteSettings;
  @service store;
  @service currentUser;

  beforeModel() {
    if (!this.siteSettings.experimental_tag_settings_page) {
      const params = this.paramsFor("tag.edit");
      return this.router.replaceWith(
        "tag.show",
        params.tag_slug,
        params.tag_id
      );
    }

    if (!this.currentUser?.canEditTags) {
      const params = this.paramsFor("tag.edit");
      return this.router.replaceWith(
        "tag.show",
        params.tag_slug,
        params.tag_id
      );
    }
  }

  async model(params) {
    const tagId = params.tag_id;
    const tagSlug = params.tag_slug;

    const tag = await this.store.find("tag-settings", `${tagSlug}/${tagId}`);
    if (tagSlug !== tag.slug) {
      return this.router.replaceWith("tag.edit", tag.slug, tag.id);
    }
    return tag;
  }

  titleToken() {
    return i18n("tagging.settings.edit_title", {
      name: this.currentModel?.name,
    });
  }
}
