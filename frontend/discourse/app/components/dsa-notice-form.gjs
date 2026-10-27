import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { array, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import Form from "discourse/components/form";
import FKContainer from "discourse/form-kit/components/fk/container";
import FKErrors from "discourse/form-kit/components/fk/errors";
import { ajax } from "discourse/lib/ajax";
import { extractError, popupAjaxError } from "discourse/lib/ajax-error";
import { emailValid, escapeExpression } from "discourse/lib/utilities";
import DOtp from "discourse/ui-kit/d-otp";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";
import { i18n } from "discourse-i18n";

export default class DsaNoticeForm extends Component {
  @service siteSettings;

  @tracked result;
  @tracked emailVerified = false;
  @tracked requestingCode = false;
  @tracked verificationError;
  @tracked verifyingCode = false;
  @tracked verificationToken;

  #form;

  get emailCodeDisabled() {
    const email = this.#form?.get("email")?.trim();
    return (
      this.emailVerified ||
      this.requestingCode ||
      this.verifyingCode ||
      !email ||
      !emailValid(email)
    );
  }

  get emailCodeLabel() {
    if (this.emailVerified) {
      return "dsa_notice.email_verified";
    }
    return this.verificationToken
      ? "dsa_notice.resend_email_code"
      : "dsa_notice.get_email_code";
  }

  @cached
  get initialData() {
    return {
      content_url: this.args.contentUrl,
      declaration: false,
    };
  }

  @action
  registerForm(form) {
    this.#form = form;
  }

  @action
  codeChanged(value) {
    this.#form.set("verification_code", value);
    this.verificationError = null;
    if (value.length === 6) {
      this.verifyCode(value);
    }
  }

  @action
  emailChanged(value, { set }) {
    set("email", value);
    set("verification_code", "");
    this.emailVerified = false;
    this.verificationError = null;
    this.verificationToken = null;
  }

  @action
  async requestCode() {
    const email = this.#form.get("email")?.trim().toLowerCase();
    if (!email || !emailValid(email)) {
      this.#form.addError("email", {
        title: i18n("dsa_notice.email"),
        message: i18n("user.email.invalid"),
      });
      return;
    }

    this.requestingCode = true;
    try {
      const result = await ajax("/dsa/report-illegal-content/verify-email", {
        type: "POST",
        data: { email },
      });
      if (this.#form.get("email")?.trim().toLowerCase() === email) {
        this.verificationToken = result.token;
        this.verificationError = null;
        this.#form.set("verification_code", "");
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.requestingCode = false;
    }
  }

  @action
  async submit(data) {
    const notice = { ...data };
    delete notice.verification_code;
    try {
      this.result = await ajax("/dsa/report-illegal-content", {
        type: "POST",
        data: { notice, token: this.verificationToken },
      });
      window.scrollTo(0, 0);
    } catch (error) {
      if (error.jqXHR?.responseJSON?.error_type === "verification_required") {
        this.emailVerified = false;
        this.verificationToken = null;
        this.verificationError = null;
        this.#form.set("verification_code", "");
      }
      popupAjaxError(error);
    }
  }

  @action
  async verifyCode(verification_code) {
    if (this.verifyingCode || this.emailVerified) {
      return;
    }

    this.verifyingCode = true;
    try {
      await ajax("/dsa/report-illegal-content/verify-code", {
        type: "POST",
        data: {
          token: this.verificationToken,
          email: this.#form.get("email")?.trim().toLowerCase(),
          verification_code,
        },
      });
      this.emailVerified = true;
    } catch (error) {
      this.verificationError =
        error.jqXHR?.responseJSON?.errors?.[0] || extractError(error);
    } finally {
      this.verifyingCode = false;
    }
  }

  @action
  validateEmail(name, value, { addError }) {
    if (value && !emailValid(value.trim())) {
      addError(name, {
        title: i18n("dsa_notice.email"),
        message: i18n("user.email.invalid"),
      });
    }
  }

  <template>
    <div class="dsa-notice" ...attributes>
      {{#if this.result}}
        <h1 tabindex="-1" {{dAutoFocus}}>{{i18n "dsa_notice.received"}}</h1>
        <p>{{i18n
            "dsa_notice.received_description"
            site=this.siteSettings.title
          }}</p>
        <p class="dsa-notice__reference">
          {{trustHTML
            (i18n
              "dsa_notice.reference"
              reference=(escapeExpression this.result.reference)
            )
          }}
        </p>
        <p>{{i18n "dsa_notice.contact_confirmation"}}</p>
      {{else}}
        <h1>{{i18n "dsa_notice.title"}}</h1>
        <FKContainer @direction="column" @format="max">
          <Form
            @data={{this.initialData}}
            @onRegisterApi={{this.registerForm}}
            @onSubmit={{this.submit}}
            as |form|
          >
            <form.Section>
              <form.Fieldset
                aria-busy={{or this.requestingCode this.verifyingCode}}
                aria-label={{i18n "dsa_notice.email"}}
                disabled={{or this.requestingCode this.verifyingCode}}
              >
                <form.Field
                  @disabled={{or this.emailVerified this.verifyingCode}}
                  @format="full"
                  @name="email"
                  @onSet={{this.emailChanged}}
                  @title={{i18n "dsa_notice.email"}}
                  @type="input-email"
                  @validate={{this.validateEmail}}
                  @validation="required"
                  as |field|
                >
                  <form.Actions>
                    <field.Control autocomplete="email" />
                    <form.Button
                      aria-live="polite"
                      class={{if
                        this.emailVerified
                        "btn-success"
                        "btn-default"
                      }}
                      @action={{this.requestCode}}
                      @disabled={{this.emailCodeDisabled}}
                      @icon={{if this.emailVerified "check"}}
                      @isLoading={{this.requestingCode}}
                      @label={{this.emailCodeLabel}}
                    />
                  </form.Actions>
                </form.Field>
                {{#if (and this.verificationToken (not this.emailVerified))}}
                  <form.Field
                    class={{if this.verificationError "has-error"}}
                    @disabled={{this.verifyingCode}}
                    @format="full"
                    @name="verification_code"
                    @title={{i18n "dsa_notice.verification_code"}}
                    @type="custom"
                    @validation="required"
                    as |field|
                  >
                    <form.Actions>
                      {{#each (array this.verificationToken) key="@identity"}}
                        <DOtp
                          aria-describedby={{if
                            this.verificationError
                            field.errorId
                          }}
                          aria-invalid={{if this.verificationError "true"}}
                          id={{field.id}}
                          @onChange={{this.codeChanged}}
                        />
                      {{/each}}
                      {{#if this.verifyingCode}}
                        <div aria-label={{i18n "loading"}} role="status">
                          {{dLoadingSpinner size="small"}}
                        </div>
                      {{/if}}
                    </form.Actions>
                    {{#if this.verificationError}}
                      <FKErrors
                        @error={{hash messages=(array this.verificationError)}}
                        @id={{field.errorId}}
                      />
                    {{/if}}
                  </form.Field>
                {{/if}}
              </form.Fieldset>
              <form.Field
                @disabled={{not this.emailVerified}}
                @format="full"
                @name="name"
                @title={{i18n "dsa_notice.name"}}
                @type="input"
                @validation="required:trim|length:1,200"
                as |field|
              >
                <field.Control autocomplete="name" />
              </form.Field>
              <form.Field
                @disabled={{not this.emailVerified}}
                @format="full"
                @name="content_url"
                @title={{i18n "dsa_notice.content_url"}}
                @type="input-url"
                @validation="required|url"
                as |field|
              >
                <field.Control />
              </form.Field>
              <form.Field
                @description={{i18n "dsa_notice.explanation_help"}}
                @disabled={{not this.emailVerified}}
                @format="full"
                @name="explanation"
                @title={{i18n "dsa_notice.explanation"}}
                @type="textarea"
                @validation="required:trim|length:50,20000"
                as |field|
              >
                <field.Control rows="6" />
              </form.Field>
              <form.Field
                @disabled={{not this.emailVerified}}
                @format="full"
                @name="declaration"
                @title={{i18n "dsa_notice.declaration_section"}}
                @type="checkbox"
                @validation="accepted"
                as |field|
              >
                <field.Control @title={{i18n "dsa_notice.declaration"}} />
              </form.Field>
              <form.Actions>
                <form.Submit
                  @disabled={{not this.emailVerified}}
                  @label="dsa_notice.submit"
                />
              </form.Actions>
            </form.Section>
          </Form>
        </FKContainer>
      {{/if}}
    </div>
  </template>
}
