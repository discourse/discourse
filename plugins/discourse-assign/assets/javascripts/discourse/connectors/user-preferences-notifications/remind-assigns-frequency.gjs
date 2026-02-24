/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import RemindAssignsFrequency from "../../components/remind-assigns-frequency";

@tagName("")
export default class RemindAssignsFrequencyConnector extends Component {
  static shouldRender(args, context) {
    return context.currentUser?.can_assign;
  }

  <template>
    <div
      class="user-preferences-notifications-outlet remind-assigns-frequency"
      ...attributes
    >
      <RemindAssignsFrequency @user={{this.model}} />
    </div>
  </template>
}
