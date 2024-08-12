import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import hideApplicationHeaderButtons from "discourse/helpers/hide-application-header-buttons";
import hideApplicationSidebar from "discourse/helpers/hide-application-sidebar";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { wavingHandURL } from "discourse/lib/waving-hand-url";
import i18n from "discourse-common/helpers/i18n";

export default RouteTemplate(
  class extends Component {
    @service siteSettings;

    @tracked accountActivated = false;
    @tracked isLoading = false;
    @tracked needsApproval = false;
    @tracked errorMessage = null;

    @action
    async activate() {
      this.isLoading = true;

      let hp;
      try {
        const response = await fetch("/session/hp", {
          headers: {
            Accept: "application/json",
          },
        });
        hp = await response.json();
      } catch (error) {
        this.isLoading = false;
        popupAjaxError(error);
        return;
      }

      try {
        const response = await ajax(
          `/u/activate-account/${this.args.model.token}.json`,
          {
            type: "PUT",
            data: {
              password_confirmation: hp.value,
              challenge: hp.challenge.split("").reverse().join(""),
            },
          }
        );

        if (!response.success) {
          this.errorMessage = i18n("user.activate_account.already_done");
          return;
        }

        this.accountActivated = true;

        if (response.redirect_to) {
          window.location.href = response.redirect_to;
        } else if (response.needs_approval) {
          this.needsApproval = true;
        } else {
          setTimeout(() => (window.location.href = "/"), 2000);
        }
      } catch (error) {
        this.errorMessage = i18n("user.activate_account.already_done");
      }
    }

    <template>
      {{hideApplicationSidebar}}
      {{hideApplicationHeaderButtons "search" "login" "signup"}}
      <div id="simple-container">
        {{#if this.errorMessage}}
          <div class="alert alert-error">
            {{this.errorMessage}}
          </div>
        {{else}}
          <div class="activate-account">
            <h1 class="activate-title">{{i18n
                "user.activate_account.welcome_to"
                site_name=this.siteSettings.title
              }}
              <img src={{(wavingHandURL)}} alt="" class="waving-hand" />
            </h1>
            <br />
            {{#if this.accountActivated}}
              <div class="perform-activation">
                <div class="image">
                  <img
                    src="/images/wizard/tada.svg"
                    class="waving-hand"
                    alt="tada emoji"
                  />
                </div>
                {{#if this.needsApproval}}
                  <p>{{i18n "user.activate_account.approval_required"}}</p>
                {{else}}
                  <p>{{i18n "user.activate_account.please_continue"}}</p>
                  <p>
                    <DButton
                      class="continue-button"
                      @translatedLabel={{i18n
                        "user.activate_account.continue_button"
                        site_name=this.siteSettings.title
                      }}
                      @href="/"
                    />
                  </p>
                {{/if}}
              </div>
            {{else}}
              <DButton
                id="activate-account-button"
                class="btn-primary"
                @action={{this.activate}}
                @label="user.activate_account.action"
                @disabled={{this.isLoading}}
              />
            {{/if}}
          </div>
        {{/if}}
      </div>
    </template>
  }
);
