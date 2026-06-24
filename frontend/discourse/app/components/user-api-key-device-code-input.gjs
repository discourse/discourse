import Component from "@glimmer/component";
import { action } from "@ember/object";
import DOtp from "discourse/ui-kit/d-otp";
import { i18n } from "discourse-i18n";

export default class UserApiKeyDeviceCodeInput extends Component {
  @action
  normalizeCode(value) {
    return value
      .toUpperCase()
      .replace(/[^A-Z0-9]/g, "")
      .slice(0, 8);
  }

  <template>
    <DOtp
      @slots={{8}}
      @groupSize={{4}}
      @inputMode="text"
      @autocomplete="off"
      @normalizeInput={{this.normalizeCode}}
      @onChange={{@onChange}}
      @onFill={{@onFill}}
      aria-label={{i18n "user_api_key.device.code"}}
      class="authorize-api-key__code-input"
      data-1p-ignore="true"
      data-lpignore="true"
      data-bwignore="true"
      data-form-type="other"
      ...attributes
    />
  </template>
}
