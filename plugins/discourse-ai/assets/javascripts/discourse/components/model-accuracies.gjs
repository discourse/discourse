import { i18n } from "discourse-i18n";

const ModelAccuracies = <template>
  {{#if @accuracies}}
    <table class="reviewable-scores">
      <tbody>
        {{#each-in @accuracies as |model acc|}}
          <tr>
            <td colspan="4">{{i18n "discourse_ai.reviewables.model_used"}}</td>
            <td colspan="3">{{model}}</td>
            <td colspan="4">{{i18n "discourse_ai.reviewables.accuracy"}}</td>
            <td colspan="3">{{acc}}%</td>
          </tr>
        {{/each-in}}
      </tbody>
    </table>
  {{/if}}
</template>;

export default ModelAccuracies;
