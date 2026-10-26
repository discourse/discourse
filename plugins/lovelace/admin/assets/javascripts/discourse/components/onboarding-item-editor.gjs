import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import OnboardingDestination from "./onboarding-destination.gjs";

export default class OnboardingItemEditor extends Component {
  @service dialog;

  @tracked saving = false;

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
  changeLinkType(value, { set }) {
    set("link_type", value);
    set("url", "");
  }

  @action
  async beforeClose() {
    if (this.saving) {
      return false;
    }
    return (
      !this.#form?.isDirty ||
      (await this.dialog.yesNoConfirm({
        message: i18n("form_kit.dirty_form"),
      }))
    );
  }

  @action
  async cancel() {
    if (await this.beforeClose()) {
      this.args.closeModal();
    }
  }

  @action
  async save(draft) {
    this.saving = true;
    try {
      if (await this.args.model.onSave(draft)) {
        this.args.closeModal();
      }
    } finally {
      this.saving = false;
    }
  }

  <template>
    <DModal
      class="lovelace-onboarding-editor"
      ...attributes
      @beforeClose={{this.beforeClose}}
      @closeModal={{@closeModal}}
      @dismissable={{not this.saving}}
      @title={{i18n @model.title}}
    >
      <:body>
        <Form
          class="lovelace-onboarding__editor"
          @commitOnSubmit={{false}}
          @data={{@model.item}}
          @onRegisterApi={{this.registerForm}}
          @onSubmit={{this.save}}
          as |form data|
        >
          <form.Field
            @disabled={{this.saving}}
            @format="full"
            @name="title"
            @title={{i18n "lovelace.onboarding.fields.title"}}
            @type="input"
            @validation="required"
            as |field|
          >
            <field.Control maxlength={{120}} />
          </form.Field>
          <form.Field
            @disabled={{this.saving}}
            @format="full"
            @name="description"
            @title={{i18n "lovelace.onboarding.fields.description"}}
            @type="textarea"
            as |field|
          >
            <field.Control maxlength={{1000}} />
          </form.Field>
          <form.Field
            @disabled={{this.saving}}
            @format="full"
            @name="link_type"
            @onSet={{this.changeLinkType}}
            @title={{i18n "lovelace.onboarding.fields.link_type"}}
            @type="select"
            @validation="required"
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
              @disabled={{this.saving}}
              @format="full"
              @name="url"
              @title={{if
                (eq data.link_type "custom")
                (i18n "lovelace.onboarding.fields.url")
                (i18n (concat "lovelace.onboarding.links." data.link_type))
              }}
              @type={{if (eq data.link_type "custom") "input" "custom"}}
              @validation="required"
              as |field|
            >
              {{#if (eq data.link_type "custom")}}
                <field.Control maxlength={{2048}} />
              {{else}}
                <field.Control>
                  <OnboardingDestination
                    @disabled={{field.disabled}}
                    @id={{field.id}}
                    @onChange={{field.set}}
                    @type={{data.link_type}}
                    @value={{field.value}}
                  />
                </field.Control>
              {{/if}}
            </form.Field>
          {{/if}}
          <form.Field
            @disabled={{this.saving}}
            @format="full"
            @name="button_text"
            @title={{i18n "lovelace.onboarding.fields.button_text"}}
            @type="input"
            @validation="required"
            as |field|
          >
            <field.Control maxlength={{80}} />
          </form.Field>
          <div class="lovelace-onboarding__actions">
            <form.Submit
              @disabled={{this.saving}}
              @label="lovelace.onboarding.save_item"
            />
            <DButton
              class="btn-default"
              @action={{this.cancel}}
              @disabled={{this.saving}}
              @label="cancel"
            />
          </div>
        </Form>
      </:body>
    </DModal>
  </template>
}
