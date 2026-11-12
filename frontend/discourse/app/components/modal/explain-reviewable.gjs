import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ScoreValue from "discourse/components/score-value";
import float from "discourse/helpers/float";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

/**
 * @typedef {import("discourse/models/rest").default & { id: number, total_score: number, min_score_visibility: number, hide_post_score: number, scores: { user_id: number, type_bonus: number, trust_level_bonus: number | string, take_action_bonus: number, flags_agreed: number, flags_disagreed: number, flags_ignored: number, user_accuracy_bonus: number, score: number }[] }} ReviewableExplanation
 */
export default class ExplainReviewable extends Component {
  @service store;

  @tracked loading = true;

  /** @type {ReviewableExplanation | null} */
  @tracked reviewableExplanation = null;

  constructor() {
    super(...arguments);
    this.loadExplanation();
  }

  @action
  async loadExplanation() {
    try {
      const result = await this.store.find(
        "reviewable-explanation",
        this.args.model.reviewable.id
      );
      this.reviewableExplanation = result;
    } finally {
      this.loading = false;
    }
  }

  <template>
    <DModal
      class="explain-reviewable"
      @closeModal={{@closeModal}}
      @title={{i18n "review.explain.title"}}
    >
      <:body>
        <DConditionalLoadingSpinner @condition={{this.loading}}>
          <table>
            <tbody>
              <tr>
                <th>{{i18n "review.explain.formula"}}</th>
                <th>{{i18n "review.explain.subtotal"}}</th>
              </tr>
              {{#each this.reviewableExplanation.scores as |s|}}
                <tr>
                  <td>
                    <ScoreValue @value="1.0" />
                    <ScoreValue @label="type_bonus" @value={{s.type_bonus}} />
                    <ScoreValue
                      @label="take_action_bonus"
                      @value={{s.take_action_bonus}}
                    />
                    <ScoreValue
                      @label="trust_level_bonus"
                      @value={{s.trust_level_bonus}}
                    />
                    <ScoreValue
                      @label="user_accuracy_bonus"
                      @value={{s.user_accuracy_bonus}}
                    />
                  </td>
                  <td class="sum">{{float s.score}}</td>
                </tr>
              {{/each}}
              <tr class="total">
                <td>{{i18n "review.explain.total"}}</td>
                <td class="sum">
                  {{float this.reviewableExplanation.total_score}}
                </td>
              </tr>
            </tbody>
          </table>

          <table class="thresholds">
            <tbody>
              <tr>
                <td>{{i18n "review.explain.min_score_visibility"}}</td>
                <td class="sum">
                  {{float this.reviewableExplanation.min_score_visibility}}
                </td>
              </tr>
              <tr>
                <td>{{i18n "review.explain.score_to_hide"}}</td>
                <td class="sum">
                  {{float this.reviewableExplanation.hide_post_score}}
                </td>
              </tr>
            </tbody>
          </table>
        </DConditionalLoadingSpinner>
      </:body>
      <:footer>
        <DButton @action={{@closeModal}} @label="close" />
      </:footer>
    </DModal>
  </template>
}
