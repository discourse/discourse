import { eq } from "truth-helpers";

const FKControlConditionalContentItem = <template>
  {{#if (eq @name @activeName)}}
    <div class="d-form__conditional-display__content">
      {{yield}}
    </div>
  {{/if}}
</template>;

export default FKControlConditionalContentItem;
