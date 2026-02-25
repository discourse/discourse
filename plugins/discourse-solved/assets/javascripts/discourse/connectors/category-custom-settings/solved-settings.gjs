import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";

export default class SolvedSettings extends Component {
  static shouldRender(args, context) {
    return !context.siteSettings.enable_simplified_category_creation;
  }

  @service siteSettings;

  @tracked
  enableAcceptedAnswers =
    this.args.outletArgs.category.custom_fields.enable_accepted_answers ===
    "true";

  @tracked
  notifyOnStaffAcceptSolved =
    this.args.outletArgs.category.custom_fields
      ?.notify_on_staff_accept_solved !== "false";

  @tracked
  emptyBoxOnUnsolved =
    this.args.outletArgs.category.custom_fields?.empty_box_on_unsolved !==
    "false";

  get customFields() {
    return this.args.outletArgs.category.custom_fields;
  }

  @action
  onChangeSetting(event) {
    this.enableAcceptedAnswers = event.target.checked;
    this.customFields.enable_accepted_answers = event.target.checked
      ? "true"
      : "false";
  }

  @action
  onChangeNotifyOnStaffAcceptSolved(value) {
    this.notifyOnStaffAcceptSolved = value;
    this.customFields.notify_on_staff_accept_solved = value ? "true" : "false";
  }

  @action
  onChangeEmptyBoxOnUnsolved(value) {
    this.emptyBoxOnUnsolved = value;
    this.customFields.empty_box_on_unsolved = value ? "true" : "false";
  }

  @action
  onChangeAutoCloseHours(value) {
    this.customFields.solved_topics_auto_close_hours = value;
  }

  <template>
    {{#if this.siteSettings.enable_simplified_category_creation}}
      <@outletArgs.form.Section @title={{i18n "solved.title"}} ...attributes>
        {{#unless this.siteSettings.allow_solved_on_all_topics}}
          <@outletArgs.form.Container>
            <label class="checkbox-label">
              <input
                type="checkbox"
                checked={{this.enableAcceptedAnswers}}
                {{on "change" this.onChangeSetting}}
              />
              {{i18n "solved.allow_accepted_answers"}}
            </label>
          </@outletArgs.form.Container>
        {{/unless}}

        <@outletArgs.form.Container
          @title={{i18n "solved.solved_topics_auto_close_hours"}}
        >
          <input
            {{on "input" (withEventValue this.onChangeAutoCloseHours)}}
            value={{this.customFields.solved_topics_auto_close_hours}}
            type="number"
            min="0"
            id="auto-close-solved-topics"
          />
        </@outletArgs.form.Container>
      </@outletArgs.form.Section>
    {{else}}
      <div
        class="category-custom-settings-outlet solved-settings"
        ...attributes
      >
        <h3>{{i18n "solved.title"}}</h3>

        {{#unless this.siteSettings.allow_solved_on_all_topics}}
          <section class="field">
            <div class="enable-accepted-answer">
              <label class="checkbox-label">
                <input
                  type="checkbox"
                  checked={{this.enableAcceptedAnswers}}
                  {{on "change" this.onChangeSetting}}
                />
                {{i18n "solved.allow_accepted_answers"}}
              </label>
            </div>
          </section>
        {{/unless}}

        <section class="field auto-close-solved-topics">
          <label for="auto-close-solved-topics">
            {{i18n "solved.solved_topics_auto_close_hours"}}
          </label>
          <input
            {{on "input" (withEventValue this.onChangeAutoCloseHours)}}
            value={{this.customFields.solved_topics_auto_close_hours}}
            type="number"
            min="0"
            id="auto-close-solved-topics"
          />
        </section>

        <section class="field notify-on-staff-accept-solved">
          <label class="checkbox-label">
            <input
              {{on
                "change"
                (withEventValue
                  this.onChangeNotifyOnStaffAcceptSolved "target.checked"
                )
              }}
              checked={{this.notifyOnStaffAcceptSolved}}
              type="checkbox"
            />
            {{i18n "solved.notify_on_staff_accept_solved"}}
          </label>
        </section>

        <section class="field empty-box-on-unsolved">
          <label class="checkbox-label">
            <input
              {{on
                "change"
                (withEventValue
                  this.onChangeEmptyBoxOnUnsolved "target.checked"
                )
              }}
              checked={{this.emptyBoxOnUnsolved}}
              type="checkbox"
            />
            {{i18n "solved.empty_box_on_unsolved"}}
          </label>
        </section>
      </div>
    {{/if}}
  </template>
}
