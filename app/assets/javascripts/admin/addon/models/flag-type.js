import discourseComputed from "discourse/lib/decorators";
import RestModel from "discourse/models/rest";
import { i18n } from "discourse-i18n";

export default class FlagType extends RestModel {
  @discourseComputed("id")
  name(id) {
    return i18n(`admin.flags.summary.action_type_${id}`, { count: 1 });
  }
}
