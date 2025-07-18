import Component from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { classNames, tagName } from "@ember-decorators/component";
import $ from "jquery";
import icon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
import cookie from "discourse/lib/cookie";
import { i18n } from "discourse-i18n";

let numTopicsOpened = 0;
const cookieName = "PatreonDonationPromptClosed";
export function incrementTopicsOpened() {
  numTopicsOpened++;
}

@tagName("div")
@classNames("topic-above-footer-buttons-outlet", "patreon")
export default class Patreon extends Component {
  static shouldRender(_args, context) {
    return context.currentUser;
  }

  init() {
    super.init(...arguments);
    this.didInsertElement = function () {
      const showDonationPrompt =
        this.siteSettings.patreon_enabled &&
        this.siteSettings.patreon_donation_prompt_enabled &&
        this.siteSettings.patreon_donation_prompt_campaign_url !== "" &&
        this.currentUser.show_donation_prompt &&
        cookie(cookieName) !== "t" &&
        numTopicsOpened >
          this.siteSettings.patreon_donation_prompt_show_after_topics;
      this.set("showDonationPrompt", showDonationPrompt);
    };
  }

  @action
  close() {
    // hide the donation prompt for 30 days
    const expires = moment().add(30, "d").toDate();
    cookie(cookieName, "t", {
      expires,
    });
    $(this.element).fadeOut(700);
  }

  <template>
    {{#if this.showDonationPrompt}}
      <div class="patreon-donation-prompt">
        <span {{on "click" this.close}} role="button" class="close">
          {{icon "xmark"}}
        </span>

        {{htmlSafe
          (i18n
            "patreon.donation_prompt.body"
            campaignUrl=this.siteSettings.patreon_donation_prompt_campaign_url
          )
        }}
      </div>
    {{/if}}
  </template>
}
