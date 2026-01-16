import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

export default class TagSettings extends RestModel {
  async save() {
    const data = {
      name: this.name,
      slug: this.slug,
      description: this.description,
    };

    const result = await ajax(`/tag/${this.id}/settings.json`, {
      type: "PUT",
      data: { tag_settings: data },
    });

    if (result.tag_settings) {
      this.setProperties(result.tag_settings);
    }

    return result;
  }
}
