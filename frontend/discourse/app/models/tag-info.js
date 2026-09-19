import RestCompatModel from "discourse/data/rest-compat";
import { TagInfoSchema } from "discourse/data/schemas/tag-info";
import { defineFieldForwarders } from "discourse/data/warp-rest-model";

export default class TagInfo extends RestCompatModel {
  static type = "tag-info";
}

defineFieldForwarders(TagInfo, TagInfoSchema);
