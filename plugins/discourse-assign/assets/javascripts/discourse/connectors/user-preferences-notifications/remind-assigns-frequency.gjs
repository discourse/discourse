import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import RemindAssignsFrequency0 from "../../components/remind-assigns-frequency";

@tagName("div")
@classNames("user-preferences-notifications-outlet", "remind-assigns-frequency")
export default class RemindAssignsFrequency extends Component {
  static shouldRender(args, context) {
    return context.currentUser?.can_assign;
  }

  <template><RemindAssignsFrequency0 @user={{this.model}} /></template>
}
