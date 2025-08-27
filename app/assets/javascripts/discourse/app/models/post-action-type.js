import { equal } from "@ember/object/computed";
import discourseComputed from "discourse/lib/decorators";
import RestModel from "discourse/models/rest";
import { i18n } from "discourse-i18n";

export const MAX_MESSAGE_LENGTH = 500;

export default class PostActionType extends RestModel {
  @equal("name_key", "illegal") isIllegal;

  @discourseComputed()
  translatedDescription() {
    if (this.system) {
      return i18n(`post.actions.by_you.${this.name_key}`);
    }
    return i18n(`post.actions.by_you.custom`, {
      custom: this.name,
    });
  }
}
