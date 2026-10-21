import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { eq, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class OnboardingItemEditor extends Component {
  @service dialog;

  #form;

  get linkTypes() {
    return [
      "custom",
      "category",
      "topic",
      "chat",
      "profile",
      "notifications",
      "account",
    ].map((value) => ({
      value,
      label: i18n(`lovelace.onboarding.links.${value}`),
    }));
  }

  @action
  registerForm(api) {
    this.#form = api;
  }

  @action
  cancel() {
    if (this.#form.isDirty) {
      this.dialog.yesNoConfirm({
        message: i18n("form_kit.dirty_form"),
        didConfirm: this.args.onCancel,
      });
    } else {
      this.args.onCancel();
    }
  }

  <template>
    <Form
      class="lovelace-onboarding__editor"
      ...attributes
      @commitOnSubmit={{false}}
      @data={{@item}}
      @onRegisterApi={{this.registerForm}}
      @onSubmit={{@onSave}}
      as |form data|
    >
      <form.Field
        @name="title"
        @title={{i18n "lovelace.onboarding.fields.title"}}
        @type="input"
        @validation="required"
        as |field|
      >
        <field.Control maxlength={{120}} />
      </form.Field>
      <form.Field
        @name="description"
        @title={{i18n "lovelace.onboarding.fields.description"}}
        @type="textarea"
        as |field|
      >
        <field.Control maxlength={{1000}} />
      </form.Field>
      <form.Field
        @name="link_type"
        @title={{i18n "lovelace.onboarding.fields.link_type"}}
        @type="select"
        as |field|
      >
        <field.Control as |control|>
          {{#each this.linkTypes as |linkType|}}
            <control.Option
              @value={{linkType.value}}
            >{{linkType.label}}</control.Option>
          {{/each}}
        </field.Control>
      </form.Field>
      {{#if
        (or
          (eq data.link_type "custom")
          (eq data.link_type "category")
          (eq data.link_type "topic")
          (eq data.link_type "chat")
        )
      }}
        <form.Field
          @helpText={{i18n "lovelace.onboarding.url_help"}}
          @name="url"
          @title={{i18n "lovelace.onboarding.fields.url"}}
          @type="input"
          @validation="required"
          as |field|
        >
          <field.Control maxlength={{2048}} />
        </form.Field>
      {{/if}}
      <form.Field
        @name="button_text"
        @title={{i18n "lovelace.onboarding.fields.button_text"}}
        @type="input"
        @validation="required"
        as |field|
      >
        <field.Control maxlength={{80}} />
      </form.Field>
      <div class="lovelace-onboarding__actions">
        <form.Submit @label={{i18n "lovelace.onboarding.save_item"}} />
        <DButton
          class="btn-default"
          @action={{this.cancel}}
          @disabled={{@saving}}
          @label="cancel"
        />
      </div>
    </Form>
  </template>
}
