/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import RemindAssignsFrequency from "../../components/remind-assigns-frequency";

@tagName("div")
@classNames("user-preferences-notifications-outlet", "remind-assigns-frequency")
export default class RemindAssignsFrequencyConnector extends Component {
  static shouldRender(args, context) {
    return context.currentUser?.can_assign;
  }

  <template><RemindAssignsFrequency @user={{this.model}} /></template>
}
