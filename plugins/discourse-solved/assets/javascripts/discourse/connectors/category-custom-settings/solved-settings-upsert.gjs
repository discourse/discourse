import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class SolvedSettingsUpsert extends Component {
  static shouldRender(args, context) {
    // NOTE: There is a separate Support tab when the solved plugin
    // is enabled for a category. In future, we may want to get rid
    // of this component entirely and just rely on the schema defined
    // in Categories::Types::Support.
    return (
      context.siteSettings.enable_simplified_category_creation &&
      (!args.category?.isType("support") ||
        !context.siteSettings.enable_support_category_type_setup)
    );
  }

  @service siteSettings;

  get enableAcceptedAnswers() {
    const value =
      this.args.outletArgs.transientData?.custom_fields
        ?.enable_accepted_answers;
    return value?.toString() === "true";
  }

  get notifyOnStaffAcceptSolved() {
    const value =
      this.args.outletArgs.transientData?.custom_fields
        ?.notify_on_staff_accept_solved;
    return value?.toString() !== "false";
  }

  get emptyBoxOnUnsolved() {
    const value =
      this.args.outletArgs.transientData?.custom_fields?.empty_box_on_unsolved;
    return value?.toString() !== "false";
  }

  @action
  async onToggleAcceptedAnswers(_, { set, name }) {
    await set(name, this.enableAcceptedAnswers ? "false" : "true");
  }

  @action
  async onToggleNotifyOnStaffAcceptSolved(_, { set, name }) {
    await set(name, this.notifyOnStaffAcceptSolved ? "false" : "true");
  }

  @action
  async onToggleEmptyBoxOnUnsolved(_, { set, name }) {
    await set(name, this.emptyBoxOnUnsolved ? "false" : "true");
  }

  <template>
    {{#let @outletArgs.form as |form|}}
      <form.Section @title={{i18n "solved.title"}}>
        <form.Object @name="custom_fields" as |customFields|>
          {{#unless this.siteSettings.allow_solved_on_all_topics}}
            <customFields.Field
              @name="enable_accepted_answers"
              @title={{i18n "solved.allow_accepted_answers"}}
              @onSet={{this.onToggleAcceptedAnswers}}
              @type="checkbox"
              as |field|
            >
              <field.Control checked={{this.enableAcceptedAnswers}} />
            </customFields.Field>
          {{/unless}}

          <customFields.Field
            @name="solved_topics_auto_close_hours"
            @title={{i18n "solved.solved_topics_auto_close_hours"}}
            @type="input-number"
            as |field|
          >
            <field.Control min="0" />
          </customFields.Field>

          <customFields.Field
            @name="notify_on_staff_accept_solved"
            @title={{i18n "solved.notify_on_staff_accept_solved"}}
            @onSet={{this.onToggleNotifyOnStaffAcceptSolved}}
            @type="checkbox"
            as |field|
          >
            <field.Control checked={{this.notifyOnStaffAcceptSolved}} />
          </customFields.Field>

          <customFields.Field
            @name="empty_box_on_unsolved"
            @title={{i18n "solved.empty_box_on_unsolved"}}
            @onSet={{this.onToggleEmptyBoxOnUnsolved}}
            @type="checkbox"
            as |field|
          >
            <field.Control checked={{this.emptyBoxOnUnsolved}} />
          </customFields.Field>
        </form.Object>
      </form.Section>
    {{/let}}
  </template>
}
