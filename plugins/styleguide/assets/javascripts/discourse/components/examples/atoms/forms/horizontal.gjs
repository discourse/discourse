import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Form from "discourse/components/form";

class SettingForm extends Component {
  @tracked savedValue;
  @tracked api;

  get saved() {
    return this.savedValue ?? this.args.value;
  }

  get data() {
    return { [this.args.name]: this.saved };
  }

  get isOverridden() {
    return this.saved !== this.args.default;
  }

  @action
  registerApi(api) {
    this.api = api;
  }

  @action
  save(data) {
    this.savedValue = data[this.args.name];
  }

  @action
  resetToDefault() {
    this.api.set(this.args.name, this.args.default);
  }

  <template>
    <Form
      @data={{this.data}}
      @layout="horizontal"
      @onRegisterApi={{this.registerApi}}
      @onSubmit={{this.save}}
      as |form|
    >
      <form.Field
        @description={{@description}}
        @format={{@format}}
        @helpText={{@helpText}}
        @name={{@name}}
        @title={{@title}}
        @type={{@type}}
        @validation={{@validation}}
        as |field|
      >
        {{yield field}}
      </form.Field>

      {{#if this.api.isDirty}}
        <form.Actions>
          <form.Button
            class="btn-default ok btn-small"
            @action={{this.api.submit}}
            @ariaLabel="admin.settings.save"
            @icon="check"
          />
          <form.Button
            class="btn-default cancel btn-small"
            @action={{this.api.reset}}
            @ariaLabel="admin.settings.cancel"
            @icon="xmark"
          />
        </form.Actions>
      {{else if this.isOverridden}}
        <form.Actions>
          <form.Button
            class="btn-flat btn-small"
            @icon="clock-rotate-left"
            @title="admin.settings.history"
          />
          <form.Button
            class="btn-default btn-small"
            @action={{this.resetToDefault}}
            @icon="arrow-rotate-left"
            @title="admin.settings.reset"
          />
        </form.Actions>
      {{/if}}
    </Form>
  </template>
}

const HorizontalFormExample = <template>
  <div class="styleguide-horizontal-form__settings">
    <div class="form-kit__section-header">
      <h2 class="form-kit__section-title">Settings</h2>
    </div>

    <SettingForm
      @default="My community"
      @description="Shown in the header and in emails."
      @helpText="Keep it short."
      @name="title"
      @title="Site title"
      @type="input"
      @validation="required"
      @value="My community"
      as |field|
    >
      <field.Control />
    </SettingForm>

    <SettingForm
      @default={{4096}}
      @name="max_upload_size"
      @title="Maximum upload size"
      @type="input-number"
      @value={{4096}}
      as |field|
    >
      <field.Control @after="KB" />
    </SettingForm>

    <SettingForm
      @default="en"
      @name="default_locale"
      @title="Default locale"
      @type="select"
      @value="en"
      as |field|
    >
      <field.Control as |select|>
        <select.Option @value="en">English</select.Option>
        <select.Option @value="fr">French</select.Option>
        <select.Option @value="ja">Japanese</select.Option>
      </field.Control>
    </SettingForm>

    <SettingForm
      @default="Welcome to our community!"
      @description="Shown to new members on their first visit."
      @name="welcome_message"
      @title="Welcome message"
      @type="textarea"
      @value="Welcome to our community!"
      as |field|
    >
      <field.Control />
    </SettingForm>

    <Form @layout="horizontal" as |form|>
      <form.Container @subtitle="A container without a field." @title="Logo">
        <form.Button @icon="upload" @translatedLabel="Upload logo" />
      </form.Container>
    </Form>

    <SettingForm
      @default={{true}}
      @name="allow_uploads"
      @title="Allow uploads"
      @type="checkbox"
      @value={{true}}
      as |field|
    >
      <field.Control>Members can attach images and files to their posts.</field.Control>
    </SettingForm>

    <SettingForm
      @default={{true}}
      @name="enable_badges"
      @title="Enable badges"
      @type="checkbox"
      @value={{true}}
      as |field|
    >
      <field.Control />
    </SettingForm>

    <SettingForm
      @default={{false}}
      @name="enable_emoji"
      @title="Enable emoji"
      @type="checkbox"
      @value={{false}}
      as |field|
    >
      <field.Control />
    </SettingForm>

    <SettingForm
      @default={{true}}
      @name="enable_mentions"
      @title="Enable mentions"
      @type="checkbox"
      @value={{true}}
      as |field|
    >
      <field.Control />
    </SettingForm>

    <SettingForm
      @default={{true}}
      @name="enable_polls"
      @title="Enable polls"
      @type="checkbox"
      @value={{true}}
      as |field|
    >
      <field.Control />
    </SettingForm>

    <SettingForm
      @default=""
      @description="Applied to every page."
      @format="full"
      @name="custom_css"
      @title="Custom CSS"
      @type="code"
      @value=".d-header { background: var(--tertiary); }"
      as |field|
    >
      <field.Control @height={{120}} @lang="css" />
    </SettingForm>

    <SettingForm
      @default=""
      @description="Replies to automated emails go here."
      @name="contact_email"
      @title="Contact email"
      @type="input-email"
      @value="team@example.com"
      as |field|
    >
      <field.Control />
    </SettingForm>

    <SettingForm
      @default="noreply@example.com"
      @description="Automated emails are sent from this address."
      @name="notification_email"
      @title="Notification email"
      @type="input-email"
      @value="noreply@example.com"
      as |field|
    >
      <field.Control />
    </SettingForm>
  </div>
</template>;

export default HorizontalFormExample;
