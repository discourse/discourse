import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";

export default class FeatureVotingSettingsUpsert extends Component {
  static shouldRender(args, context) {
    return context.siteSettings.enable_simplified_category_creation;
  }

  get enableTopicVoting() {
    const value =
      this.args.outletArgs.transientData?.custom_fields?.enable_topic_voting;
    return value === "true" || value === true;
  }

  @action
  onToggleTopicVoting(value) {
    this.args.outletArgs.form.set(
      "custom_fields.enable_topic_voting",
      value ? "true" : "false"
    );
  }

  <template>
    {{#let @outletArgs.form as |form|}}
      <form.Section @title={{i18n "topic_voting.title"}}>
        <div
          class="form-kit__container form-kit__field form-kit__field-checkbox"
        >
          <div class="form-kit__container-content">
            <label class="form-kit__control-checkbox-label">
              <input
                class="form-kit__control-checkbox"
                type="checkbox"
                checked={{this.enableTopicVoting}}
                {{on
                  "change"
                  (withEventValue this.onToggleTopicVoting "target.checked")
                }}
              />
              <span class="form-kit__control-checkbox-content">
                <span class="form-kit__control-checkbox-title">
                  <span>{{i18n "topic_voting.allow_topic_voting"}}</span>
                </span>
              </span>
            </label>
          </div>
        </div>
      </form.Section>
    {{/let}}
  </template>
}
