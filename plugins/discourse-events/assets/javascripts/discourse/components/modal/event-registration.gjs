import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import FormDefinitionFields from "discourse/components/form-definition-fields";
import { extractError } from "discourse/lib/ajax-error";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class EventRegistration extends Component {
  @service currentUser;

  @tracked error;
  initialAnswers = {};

  @action
  async loadAccountEmail() {
    await this.currentUser.checkEmail();
    return this.currentUser.email;
  }

  @action
  async submit(answers) {
    if (this.args.model.onSubmit) {
      try {
        await this.args.model.onSubmit(answers);
      } catch (error) {
        this.error = extractError(error);
        return;
      }
    }
    this.args.closeModal({ submitted: true });
  }

  <template>
    <DModal
      class="event-registration"
      @closeModal={{@closeModal}}
      @flash={{this.error}}
      @flashType="error"
      @inline={{@inline}}
      @title={{i18n "event_registration.title"}}
    >
      <:body>
        <Form @data={{this.initialAnswers}} @onSubmit={{this.submit}} as |form|>
          {{#if this.currentUser}}
            <form.Field
              @format="full"
              @helpText={{i18n "event_registration.account_email_help"}}
              @name="_accountEmail"
              @showOptional={{false}}
              @title={{i18n "event_registration.account_email"}}
              @type="custom"
              as |field|
            >
              <DAsyncContent @asyncData={{this.loadAccountEmail}}>
                <:content as |email|>
                  <input
                    aria-describedby={{field.describedBy}}
                    class="form-kit__control-input"
                    id={{field.id}}
                    readonly
                    type="email"
                    value={{email}}
                  />
                </:content>
              </DAsyncContent>
            </form.Field>
          {{/if}}
          <FormDefinitionFields
            @fields={{@model.definition.fields}}
            @form={{form}}
          />
          <form.Actions><form.Submit
              @label="event_registration.submit"
            /></form.Actions>
        </Form>
      </:body>
    </DModal>
  </template>
}
