import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";

export default class ActivationControls extends Component {
  @service siteSettings;

  get canEditEmail() {
    return (
      this.siteSettings.enable_local_logins || this.siteSettings.email_editable
    );
  }

  <template>
    <div class="activation-controls">
      {{#unless this.siteSettings.must_approve_users}}
        <DButton
          @action={{@sendActivationEmail}}
          @label="login.resend_title"
          @icon="envelope"
          class="btn-primary resend"
        />
      {{/unless}}

      {{#if this.canEditEmail}}
        <DButton
          @action={{@editActivationEmail}}
          @label="login.change_email"
          @icon="pencil"
          class="edit-email"
        />
      {{/if}}
    </div>
  </template>
}
