import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import cookie from "discourse/lib/cookie";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

let numTopicsOpened = 0;
const cookieName = "PatreonDonationPromptClosed";
export function incrementTopicsOpened() {
  numTopicsOpened++;
}

export default class Patreon extends Component {
  static shouldRender(_args, context) {
    return context.currentUser;
  }

  @service currentUser;
  @service siteSettings;

  @tracked
  showDonationPrompt =
    this.siteSettings.patreon_enabled &&
    this.siteSettings.patreon_donation_prompt_enabled &&
    this.siteSettings.patreon_donation_prompt_campaign_url !== "" &&
    this.currentUser.show_donation_prompt &&
    cookie(cookieName) !== "t" &&
    numTopicsOpened >
      this.siteSettings.patreon_donation_prompt_show_after_topics;

  @action
  close() {
    // hide the donation prompt for 30 days
    const expires = moment().add(30, "d").toDate();
    cookie(cookieName, "t", {
      expires,
    });
    this.showDonationPrompt = false;
  }

  <template>
    <div class="topic-above-footer-buttons-outlet patreon" ...attributes>
      {{#if this.showDonationPrompt}}
        <div class="patreon-donation-prompt">
          <span class="close" role="button" {{on "click" this.close}}>
            {{dIcon "xmark"}}
          </span>

          {{trustHTML
            (i18n
              "patreon.donation_prompt.body"
              campaignUrl=this.siteSettings.patreon_donation_prompt_campaign_url
            )
          }}
        </div>
      {{/if}}
    </div>
  </template>
}
