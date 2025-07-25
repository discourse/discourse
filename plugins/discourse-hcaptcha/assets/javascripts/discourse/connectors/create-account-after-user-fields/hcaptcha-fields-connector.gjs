import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import HCaptcha from "../../components/h-captcha";

@tagName("")
@classNames(
  "create-account-after-user-fields-outlet",
  "hcaptcha-fields-connector"
)
export default class HcaptchaFieldsConnector extends Component {
  <template>
    <div class="input-group">
      <HCaptcha @siteKey={{this.siteSettings.hcaptcha_site_key}} />
    </div>
  </template>
}
