import RestCompatModel from "discourse/data/rest-compat";
import { TagSettingsSchema } from "discourse/data/schemas/tag-settings";
import { defineFieldForwarders } from "discourse/data/warp-rest-model";

export default class TagSettings extends RestCompatModel {
  static type = "tag-settings";
}

defineFieldForwarders(TagSettings, TagSettingsSchema);
