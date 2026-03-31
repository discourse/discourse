/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import HCaptcha from "../../components/h-captcha";
import ReCaptcha from "../../components/re-captcha";

@tagName("")
export default class CaptchaFieldsConnector extends Component {
  @service siteSettings;

  <template>
    <div
      class="create-account-after-user-fields-outlet captcha-fields-connector"
      ...attributes
    >
      <div class="input-group">
        {{#if this.siteSettings.discourse_hcaptcha_enabled}}
          <HCaptcha @siteKey={{this.siteSettings.hcaptcha_site_key}} />
        {{/if}}
        {{#if this.siteSettings.discourse_recaptcha_enabled}}
          <ReCaptcha @siteKey={{this.siteSettings.recaptcha_site_key}} />
        {{/if}}
      </div>
    </div>
  </template>
}
