/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import HCaptcha from "../../components/h-captcha";

@tagName("")
export default class HcaptchaFieldsConnector extends Component {
  <template>
    <div
      class="create-account-after-user-fields-outlet hcaptcha-fields-connector"
      ...attributes
    >
      <div class="input-group">
        <HCaptcha @siteKey={{this.siteSettings.hcaptcha_site_key}} />
      </div>
    </div>
  </template>
}
