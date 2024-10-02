import Component from "@glimmer/component";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import icon from "discourse-common/helpers/d-icon";

export default class AdminNotice extends Component {
  @action
  dismiss() {
    this.args.dismissCallback(this.args.problem);
  }

  <template>
    <div class="notice">
      <div class="message">
        {{if @icon (icon @icon)}}
        {{htmlSafe @problem.message}}
      </div>
      <DButton
        @action={{this.dismiss}}
        @label="admin.dashboard.dismiss_notice"
      />
    </div>
  </template>
}
