import Component from "@glimmer/component";
import { service } from "@ember/service";
import { eq } from "discourse/truth-helpers";
import HCaptcha from "../../components/h-captcha";
import ReCaptcha from "../../components/re-captcha";
import ReCaptchaV3 from "../../components/re-captcha-v3";

export default class CaptchaFieldsConnector extends Component {
  @service siteSettings;

  <template>
    <div
      class="create-account-after-user-fields-outlet captcha-fields-connector"
      ...attributes
    >
      <div class="input-group">
        {{#if (eq this.siteSettings.discourse_captcha_provider "hcaptcha")}}
          <HCaptcha @siteKey={{this.siteSettings.hcaptcha_site_key}} />
        {{else if
          (eq this.siteSettings.discourse_captcha_provider "recaptcha_v2")
        }}
          <ReCaptcha @siteKey={{this.siteSettings.recaptcha_v2_site_key}} />
        {{else if
          (eq this.siteSettings.discourse_captcha_provider "recaptcha_v3")
        }}
          <ReCaptchaV3 @siteKey={{this.siteSettings.recaptcha_v3_site_key}} />
        {{/if}}
      </div>
    </div>
  </template>
}
