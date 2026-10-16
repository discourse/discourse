import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import Form from "discourse/components/form";
import FKContainer from "discourse/form-kit/components/fk/container";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { emailValid, escapeExpression } from "discourse/lib/utilities";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";
import { i18n } from "discourse-i18n";

export default class DsaNoticeForm extends Component {
  @service siteSettings;

  @tracked result;

  #submissionId = this.#newSubmissionId();

  @cached
  get initialData() {
    return {
      content_url: this.args.contentUrl,
      anonymous: false,
      declaration: false,
    };
  }

  @action
  async submit(data) {
    const { name, email, ...notice } = data;
    notice.submission_id = this.#submissionId;
    if (!notice.anonymous) {
      notice.name = name;
      notice.email = email;
    }

    try {
      this.result = await ajax("/dsa/illegal-content", {
        type: "POST",
        data: { notice },
      });
      window.scrollTo(0, 0);
    } catch (error) {
      popupAjaxError(error);
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

  #newSubmissionId() {
    const bytes = crypto.getRandomValues(new Uint8Array(16));
    bytes[6] = (bytes[6] % 16) + 64;
    bytes[8] = (bytes[8] % 64) + 128;
    const hex = Array.from(bytes, (byte) =>
      byte.toString(16).padStart(2, "0")
    ).join("");
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
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
        {{#if this.result.contact}}
          <p>{{i18n "dsa_notice.contact_confirmation"}}</p>
        {{else}}
          <p>{{i18n "dsa_notice.anonymous_confirmation"}}</p>
        {{/if}}
      {{else}}
        <h1>{{i18n "dsa_notice.title" site=this.siteSettings.title}}</h1>
        <FKContainer @direction="column" @format="max">
          <Form
            @data={{this.initialData}}
            @onSubmit={{this.submit}}
            as |form draft|
          >
            <form.Section>
              <form.Field
                @format="full"
                @name="anonymous"
                @showOptional={{false}}
                @title={{i18n "dsa_notice.anonymous_label"}}
                @type="checkbox"
                as |field|
              >
                <field.Control />
              </form.Field>
              {{#unless draft.anonymous}}
                <form.Field
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
                  @format="full"
                  @name="email"
                  @title={{i18n "dsa_notice.email"}}
                  @type="input-email"
                  @validate={{this.validateEmail}}
                  @validation="required"
                  as |field|
                >
                  <field.Control autocomplete="email" />
                </form.Field>
              {{/unless}}
              <form.Field
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
                <form.Submit @label="dsa_notice.submit" />
              </form.Actions>
            </form.Section>
          </Form>
        </FKContainer>
      {{/if}}
    </div>
  </template>
}
