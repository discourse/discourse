import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import HCaptcha from "discourse/plugins/discourse-captcha/discourse/components/h-captcha";
import ReCaptcha from "discourse/plugins/discourse-captcha/discourse/components/re-captcha";

export default class CaptchaConfigurationTest extends Component {
  @service a11y;

  @tracked attempt = 0;
  @tracked challengeVisible = false;
  @tracked result;
  @tracked verifying = false;

  @action
  start() {
    this.attempt++;
    this.result = null;
    this.challengeVisible = true;
  }

  @action
  challengeFailed() {
    this.#showResult(
      {
        success: false,
        message: i18n("discourse_captcha.configuration_test.challenge_failed"),
      },
      false
    );
  }

  @action
  async verify(token) {
    if (this.verifying) {
      return;
    }

    if (!token) {
      this.#showResult({
        success: false,
        message: i18n("discourse_captcha.configuration_test.expired"),
      });
      return;
    }

    this.verifying = true;
    try {
      const result = await ajax("/admin/plugins/discourse-captcha/test.json", {
        type: "POST",
        data: {
          token,
          provider: this.args.configuration.provider,
          site_key: this.args.configuration.site_key,
        },
      });
      this.#showResult(result);
    } catch (error) {
      this.#showResult({ success: false, message: extractError(error) });
    } finally {
      if (!this.isDestroying) {
        this.verifying = false;
      }
    }
  }

  #showResult(result, hideChallenge = true) {
    if (this.isDestroying) {
      return;
    }
    if (hideChallenge) {
      this.challengeVisible = false;
    }
    this.result = result;
    this.a11y.announce(result.message);
  }

  <template>
    <div class="captcha-configuration-test" ...attributes>
      <DPageSubheader
        @descriptionLabel={{i18n
          "discourse_captcha.configuration_test.description"
        }}
        @titleLabel={{i18n "discourse_captcha.configuration_test.title"}}
      />

      {{#if @configuration.configured}}
        {{#if this.result}}
          <p
            class={{if
              this.result.success
              "alert alert-success"
              "alert alert-error"
            }}
          >
            {{this.result.message}}
          </p>
        {{/if}}
        {{#if this.challengeVisible}}
          {{#unless this.result}}
            <p>{{i18n
                "discourse_captcha.configuration_test.complete_challenge"
              }}</p>
          {{/unless}}
          {{#each (array this.attempt) key="@identity"}}
            {{#if (eq @configuration.provider "recaptcha")}}
              <ReCaptcha
                @errorMessage={{i18n
                  "discourse_captcha.configuration_test.challenge_failed"
                }}
                @onError={{this.challengeFailed}}
                @onResponse={{this.verify}}
                @siteKey={{@configuration.site_key}}
              />
            {{else}}
              <HCaptcha
                @errorMessage={{i18n
                  "discourse_captcha.configuration_test.challenge_failed"
                }}
                @onError={{this.challengeFailed}}
                @onResponse={{this.verify}}
                @siteKey={{@configuration.site_key}}
              />
            {{/if}}
          {{/each}}
          {{#if this.verifying}}
            <p>{{i18n "discourse_captcha.configuration_test.verifying"}}</p>
          {{/if}}
        {{/if}}
        {{#if this.result}}
          <DButton
            class="btn-primary captcha-configuration-test__retry"
            @action={{this.start}}
            @label="discourse_captcha.configuration_test.retry"
          />
        {{else}}
          {{#unless this.challengeVisible}}
            <DButton
              class="btn-primary"
              @action={{this.start}}
              @label="discourse_captcha.configuration_test.start"
            />
          {{/unless}}
        {{/if}}
      {{else}}
        <p class="alert alert-info">
          {{i18n "discourse_captcha.configuration_test.not_configured"}}
        </p>
      {{/if}}
    </div>
  </template>
}
