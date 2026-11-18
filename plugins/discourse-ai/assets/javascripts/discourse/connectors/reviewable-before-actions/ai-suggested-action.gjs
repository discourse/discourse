import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { PENDING } from "discourse/models/reviewable";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class AiSuggestedAction extends Component {
  get suggestedAction() {
    const { reviewable } = this.args.outletArgs;
    const name = reviewable.ai_suggested_action_name;
    if (reviewable.status === PENDING && name) {
      return reviewable.bundled_actions
        .flatMap((bundle) => bundle.actions)
        .find((action) => action.action_name === name);
    }
  }

  <template>
    {{#let this.suggestedAction as |suggestion|}}
      {{#if suggestion}}
        <DButton
          class="btn-primary ai-suggested-action"
          @action={{fn @outletArgs.performAction suggestion}}
          @disabled={{@outletArgs.disabled}}
          @icon="discourse-sparkles"
          @translatedAriaLabel={{i18n
            "discourse_ai.apply_review_suggestion"
            action=suggestion.label
          }}
          @translatedLabel={{suggestion.label}}
        />
      {{/if}}
    {{/let}}
  </template>
}
