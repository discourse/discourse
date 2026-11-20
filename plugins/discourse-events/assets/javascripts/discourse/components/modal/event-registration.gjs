import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import guid from "pretty-text/guid";
import Form from "discourse/components/form";
import FormDefinitionFields from "discourse/components/form-definition-fields";
import { extractError } from "discourse/lib/ajax-error";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class EventRegistration extends Component {
  @tracked error;
  initialAnswers = {};
  submissionKey = guid();

  @action
  async submit(answers) {
    if (this.args.model.onSubmit) {
      try {
        await this.args.model.onSubmit(answers, this.submissionKey);
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
      @title={{@model.definition.title}}
    >
      <:body>
        {{#if @model.definition.description}}<p
          >{{@model.definition.description}}</p>{{/if}}
        <p>{{i18n "event_registration.member_notice"}}</p>
        <Form @data={{this.initialAnswers}} @onSubmit={{this.submit}} as |form|>
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
