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
      aria-label={{i18n "user_api_key.device.code"}}
      class="authorize-api-key__code-input"
      data-1p-ignore="true"
      data-bwignore="true"
      data-form-type="other"
      data-lpignore="true"
      ...attributes
      @autocomplete="off"
      @groupSize={{4}}
      @inputMode="text"
      @normalizeInput={{this.normalizeCode}}
      @onChange={{@onChange}}
      @onFill={{@onFill}}
      @slots={{8}}
    />
  </template>
}
