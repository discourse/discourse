import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";

export default <template>
  {{#each @categories key="id" as |category|}}
    {{dCategoryBadge category categoryStyle="bullet"}}
  {{/each}}
</template>
