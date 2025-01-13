import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";

export default class AdminNotice extends Component {
  @service currentUser;

  @action
  dismiss() {
    this.args.dismissCallback(this.args.problem);
  }

  get canDismiss() {
    return this.currentUser.admin;
  }

  <template>
    <div class="notice">
      <div class="message">
        {{if @icon (icon @icon)}}
        {{htmlSafe @problem.message}}
      </div>
      {{#if this.canDismiss}}
        <DButton
          @action={{this.dismiss}}
          @label="admin.dashboard.dismiss_notice"
        />
      {{/if}}
    </div>
  </template>
}
