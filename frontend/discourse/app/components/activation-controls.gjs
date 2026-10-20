import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";

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
          class="btn-primary resend"
          @action={{@sendActivationEmail}}
          @icon="envelope"
          @label="login.resend_title"
        />
      {{/unless}}

      {{#if this.canEditEmail}}
        <DButton
          class="btn-default edit-email"
          @action={{@editActivationEmail}}
          @icon="pencil"
          @label="login.change_email"
        />
      {{/if}}
    </div>
  </template>
}
