import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";

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
        {{if @icon (dIcon @icon)}}
        {{trustHTML @problem.message}}
      </div>
      {{#if this.canDismiss}}
        <DButton
          @action={{this.dismiss}}
          @label="admin.dashboard.dismiss_notice"
          class="btn-default"
        />
      {{/if}}
    </div>
  </template>
}
