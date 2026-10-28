import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { withoutPrefix } from "discourse/lib/get-url";
import DiscourseURL, { applyQueryParams } from "discourse/lib/url";
import { i18n } from "discourse-i18n";

export default class AdminBotForm extends Component {
  @service a11y;
  @service router;
  @service site;
  @service siteSettings;
  @service toasts;

  @tracked errorMessage;

  @cached
  get formData() {
    return {
      name: "",
      username: "",
      trust_level: this.args.defaultTrustLevel,
    };
  }

  get usernameValidation() {
    return `required|length:${this.siteSettings.min_username_length},${this.siteSettings.max_username_length}`;
  }

  @action
  async createBot(data) {
    this.errorMessage = null;

    let user;
    try {
      ({ user } = await ajax("/admin/users/bots.json", {
        type: "POST",
        data: {
          bot: {
            name: data.name,
            username: data.username,
            trust_level: Number(data.trust_level),
          },
        },
      }));
    } catch (error) {
      this.errorMessage = extractError(error);
      this.a11y.announce(this.errorMessage, "assertive");
      return;
    }

    const botsUrl = applyQueryParams(
      this.router.urlFor("adminUsersList.show", "bots"),
      {
        filter: null,
        username: null,
        order: "created",
        asc: null,
        account_type: null,
        activation: null,
      }
    );
    await this.router.transitionTo(withoutPrefix(botsUrl));
    // The list manages sorting outside Ember's query-param registry.
    DiscourseURL.replaceState(botsUrl);
    this.toasts.success({
      duration: "short",
      data: {
        message: i18n("admin.users.bots.created", { username: user.username }),
      },
    });
  }

  <template>
    <Form
      class="admin-bot-form"
      ...attributes
      @data={{this.formData}}
      @onSubmit={{this.createBot}}
      as |form|
    >
      {{#if this.errorMessage}}
        <form.Alert @type="error">{{this.errorMessage}}</form.Alert>
      {{/if}}

      <form.Field
        @format="large"
        @name="name"
        @title={{i18n "admin.users.bots.name"}}
        @type="input"
        @validation={{if @nameRequired "required"}}
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Field
        @format="large"
        @name="username"
        @title={{i18n "admin.users.bots.username"}}
        @type="input"
        @validation={{this.usernameValidation}}
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Field
        @format="large"
        @name="trust_level"
        @title={{i18n "admin.users.bots.trust_level"}}
        @type="select"
        @validation="required"
        as |field|
      >
        <field.Control as |control|>
          {{#each this.site.trustLevels as |trustLevel|}}
            <control.Option @value={{trustLevel.id}}>
              {{trustLevel.detailedName}}
            </control.Option>
          {{/each}}
        </field.Control>
      </form.Field>

      <form.Actions>
        <form.Submit @label="admin.users.bots.create" />
        <form.Button
          class="btn-default admin-bot-form__cancel"
          @label="cancel"
          @route="adminUsersList.show"
          @routeModels="bots"
        />
      </form.Actions>
    </Form>
  </template>
}
