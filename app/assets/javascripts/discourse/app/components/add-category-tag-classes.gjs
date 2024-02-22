import { concat } from "@ember/helper";
import bodyClass from "discourse/helpers/body-class";

const AddCategoryTagClasses = <template>
  {{#if @category}}
    {{bodyClass "category" (concat "category-" @category.fullSlug)}}
  {{/if}}

  {{#each @tags as |tag|}}
    {{bodyClass (concat "tag-" tag)}}
  {{/each}}
</template>;

export default AddCategoryTagClasses;
