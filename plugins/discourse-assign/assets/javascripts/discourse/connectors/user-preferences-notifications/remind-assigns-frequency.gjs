import Component from "@glimmer/component";
import RemindAssignsFrequency from "../../components/remind-assigns-frequency.gjs";

export default class RemindAssignsFrequencyConnector extends Component {
  static shouldRender(args, context) {
    return context.currentUser?.can_assign;
  }

  <template>
    <div
      class="user-preferences-notifications-outlet remind-assigns-frequency"
      ...attributes
    >
      <RemindAssignsFrequency @user={{@model}} />
    </div>
  </template>
}
