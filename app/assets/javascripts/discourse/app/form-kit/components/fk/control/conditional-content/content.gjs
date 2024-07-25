import { eq } from "truth-helpers";

const FKControlConditionalContentItem = <template>
  {{#if (eq @name @activeName)}}
    <div class="form-kit__conditional-display-content">
      {{yield}}
    </div>
  {{/if}}
</template>;

export default FKControlConditionalContentItem;
