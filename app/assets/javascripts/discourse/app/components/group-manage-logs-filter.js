import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

@tagName("")
export default class GroupManageLogsFilter extends Component {
  @discourseComputed("type")
  label(type) {
    return I18n.t(`groups.manage.logs.${type}`);
  }

  @discourseComputed("value", "type")
  filterText(value, type) {
    return type === "action"
      ? I18n.t(`group_histories.actions.${value}`)
      : value;
  }
}
