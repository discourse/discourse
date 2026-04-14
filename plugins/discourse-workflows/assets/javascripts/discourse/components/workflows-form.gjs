import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import autoFocus from "discourse/modifiers/auto-focus";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

function isFieldType(field, type) {
  return field.field_type === type;
}

function controlType(field) {
  return field.field_type === "number" ? "number" : "text";
}

function parseDropdownOptions(field) {
  const options = field.options || [];
  return options
    .filter((opt) => opt.value)
    .map((opt) => ({ id: opt.value, name: opt.value }));
}

export default class WorkflowsForm extends Component {
  @service messageBus;

  @tracked state = "form";
  @tracked errorMessage = null;
  @tracked completionData = null;
  resumeToken = null;
  @tracked _formSchema = null;

  _channel = null;

  willDestroy() {
    super.willDestroy(...arguments);
    this.#unsubscribe();
  }

  get formSchema() {
    return this._formSchema ?? this.args.model;
  }

  set formSchema(value) {
    this._formSchema = value;
  }

  get formData() {
    const data = {};
    (this.formSchema.form_fields || []).forEach((field) => {
      const key = field.key;
      if (field.field_type === "checkbox") {
        data[key] = field.default_value === "true" || false;
      } else {
        data[key] = field.default_value || "";
      }
    });
    return data;
  }

  get fields() {
    return (this.formSchema.form_fields || []).map((field, index) => ({
      ...field,
      key: field.key,
      autofocus: index === 0,
    }));
  }

  @action
  async handleSubmit(formData) {
    this.state = "submitting";

    try {
      const payload = { form_data: formData };
      const isResume = !!this.resumeToken;

      if (isResume) {
        payload.resume_token = this.resumeToken;
      } else if (this.args.model.resume_token) {
        payload.resume_token = this.args.model.resume_token;
      }

      const result = await ajax(
        `/workflows/form/${this.args.model.uuid}.json`,
        {
          type: isResume ? "PUT" : "POST",
          data: payload,
        }
      );

      this.resumeToken = result.resume_token;

      const shouldWait =
        result.has_downstream_form ||
        result.response_mode === "workflow_finishes";

      if (shouldWait) {
        this.state = "waiting";
        this.#subscribe(result.form_channel);
      } else {
        this.state = "complete";
      }
    } catch (e) {
      this.state = "error";
      this.errorMessage =
        e?.jqXHR?.responseJSON?.error ||
        i18n("discourse_workflows.form.error_message");
    }
  }

  #subscribe(channel) {
    this.#unsubscribe();
    this._channel = channel;
    this.messageBus.subscribe(
      this._channel,
      (message) => {
        this.#handleMessage(message);
      },
      0
    );
  }

  #unsubscribe() {
    if (this._channel) {
      this.messageBus.unsubscribe(this._channel);
      this._channel = null;
    }
  }

  async #handleMessage(message) {
    if (message.status === "waiting_for_form") {
      try {
        const schema = await ajax(
          `/workflows/form/${this.args.model.uuid}.json?resume_token=${this.resumeToken}`
        );
        this.formSchema = schema;
        this.state = "form";
      } catch {
        this.state = "error";
      }
    } else if (message.status === "success") {
      this.#unsubscribe();
      const completion = message.form_completion;
      if (completion?.on_submission === "redirect" && completion.redirect_url) {
        const url = completion.redirect_url;
        try {
          if (url.startsWith("/") && !url.startsWith("//")) {
            window.location.href = url;
          } else {
            const parsed = new URL(url);
            if (parsed.origin === window.location.origin) {
              window.location.href = url;
            }
          }
        } catch {
          // invalid URL, don't redirect
        }
        return;
      }
      this.completionData = completion || null;
      this.state = "complete";
    } else if (message.status === "error") {
      this.#unsubscribe();
      this.state = "error";
    }
  }

  <template>
    <div class="workflows-form">
      {{#if (eq this.state "form")}}
        <div class="workflows-form__header">
          {{#if this.formSchema.form_title}}
            <h1
              class="workflows-form__title"
            >{{this.formSchema.form_title}}</h1>
          {{/if}}
          {{#if this.formSchema.form_description}}
            <p
              class="workflows-form__description"
            >{{this.formSchema.form_description}}</p>
          {{/if}}
        </div>

        <Form @data={{this.formData}} @onSubmit={{this.handleSubmit}} as |form|>
          {{#each this.fields as |field|}}
            {{#if (isFieldType field "checkbox")}}
              <form.Field
                @name={{field.key}}
                @title={{field.field_label}}
                @description={{field.description}}
                @type="checkbox"
                @format="full"
                as |f|
              >
                <f.Control {{(if field.autofocus (modifier autoFocus))}} />
              </form.Field>
            {{else if (isFieldType field "textarea")}}
              <form.Field
                @name={{field.key}}
                @title={{field.field_label}}
                @description={{field.description}}
                @type="textarea"
                @format="full"
                @validation={{if field.required "required"}}
                as |f|
              >
                <f.Control
                  placeholder={{field.placeholder}}
                  {{(if field.autofocus (modifier autoFocus))}}
                />
              </form.Field>
            {{else if (isFieldType field "dropdown")}}
              <form.Field
                @name={{field.key}}
                @title={{field.field_label}}
                @description={{field.description}}
                @type="select"
                @format="full"
                @validation={{if field.required "required"}}
                as |f|
              >
                <f.Control {{(if field.autofocus (modifier autoFocus))}} as |c|>
                  {{#each (parseDropdownOptions field) as |opt|}}
                    <c.Option @value={{opt.id}}>{{opt.name}}</c.Option>
                  {{/each}}
                </f.Control>
              </form.Field>
            {{else}}
              <form.Field
                @name={{field.key}}
                @title={{field.field_label}}
                @description={{field.description}}
                @type="input"
                @format="full"
                @validation={{if field.required "required"}}
                as |f|
              >
                <f.Control
                  @type={{controlType field}}
                  placeholder={{field.placeholder}}
                  {{(if field.autofocus (modifier autoFocus))}}
                />
              </form.Field>
            {{/if}}
          {{/each}}

          <form.Submit @label="discourse_workflows.form.submit" />
        </Form>
      {{else if (eq this.state "submitting")}}
        <ConditionalLoadingSpinner @condition={{true}} />
      {{else if (eq this.state "waiting")}}
        <ConditionalLoadingSpinner @condition={{true}} />
      {{else if (eq this.state "complete")}}
        <div class="workflows-form__complete">
          {{#if this.completionData}}
            {{#if (eq this.completionData.on_submission "redirect")}}
              <p>{{i18n "discourse_workflows.form.redirecting"}}</p>
            {{else if (eq this.completionData.on_submission "show_text")}}
              <p>{{this.completionData.completion_text}}</p>
            {{else}}
              {{#if this.completionData.completion_title}}
                <h2
                  class="workflows-form__completion-title"
                >{{this.completionData.completion_title}}</h2>
              {{/if}}
              {{#if this.completionData.completion_message}}
                <p
                  class="workflows-form__completion-message"
                >{{this.completionData.completion_message}}</p>
              {{else}}
                <p>{{i18n "discourse_workflows.form.thank_you"}}</p>
              {{/if}}
            {{/if}}
          {{else}}
            <p>{{i18n "discourse_workflows.form.thank_you"}}</p>
          {{/if}}
        </div>
      {{else if (eq this.state "error")}}
        <div class="workflows-form__error">
          <p>{{this.errorMessage}}</p>
        </div>
      {{/if}}
    </div>
  </template>
}
