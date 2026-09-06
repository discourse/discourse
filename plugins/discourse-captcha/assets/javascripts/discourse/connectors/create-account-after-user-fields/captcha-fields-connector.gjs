/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import { eq } from "discourse/truth-helpers";
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
        {{#if (eq this.siteSettings.discourse_captcha_provider "hcaptcha")}}
          <HCaptcha @siteKey={{this.siteSettings.hcaptcha_site_key}} />
        {{else if
          (eq this.siteSettings.discourse_captcha_provider "recaptcha")
        }}
          <ReCaptcha @siteKey={{this.siteSettings.recaptcha_site_key}} />
        {{/if}}
      </div>
    </div>
  </template>
}
