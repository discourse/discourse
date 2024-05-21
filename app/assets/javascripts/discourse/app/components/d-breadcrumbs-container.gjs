import concatClass from "discourse/helpers/concat-class";
import dBreadcrumbsContainerModifier from "discourse/modifiers/d-breadcrumbs-container-modifier";

const DBreadcrumbsContainer = <template>
  <ul
    class="d-breadcrumbs"
    {{dBreadcrumbsContainerModifier
      itemClass=(concatClass "d-breadcrumbs__item" @additionalItemClasses)
      linkClass=(concatClass "d-breadcrumbs__link" @additionalLinkClasses)
    }}
    ...attributes
  >
    {{yield}}
  </ul>
</template>;

export default DBreadcrumbsContainer;
