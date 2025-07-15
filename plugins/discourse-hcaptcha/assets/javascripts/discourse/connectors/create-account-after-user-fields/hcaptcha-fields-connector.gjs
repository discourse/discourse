import Component from "@ember/component";
import { service } from "@ember/service";
import { classNames, tagName } from "@ember-decorators/component";
import HCaptcha from "../../components/h-captcha";
import ReCaptcha from "../../components/re-captcha";

@tagName("")
@classNames(
  "create-account-after-user-fields-outlet",
  "hcaptcha-fields-connector"
)
export default class HcaptchaFieldsConnector extends Component {
  @service siteSettings;

  <template>
    <div class="input-group">
      {{#if this.siteSettings.discourse_hcaptcha_enabled}}
        <HCaptcha @siteKey={{this.siteSettings.recaptcha_site_key}} />
      {{/if}}
      {{#if this.siteSettings.discourse_recaptcha_enabled}}
        <ReCaptcha @siteKey={{this.siteSettings.recaptcha_site_key}} />
      {{/if}}
    </div>
  </template>
}
