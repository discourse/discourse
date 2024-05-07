import BreadcrumbsContainer from "discourse/components/breadcrumbs-container";
import concatClass from "discourse/helpers/concat-class";

const DBreadcrumbsContainer = <template>
  <BreadcrumbsContainer
    @itemClass={{concatClass "d-breadcrumbs__item" @itemClass}}
    @linkClass={{concatClass "d-breadcrumbs__link" @linkClass}}
    class="d-breadcrumbs"
  />
</template>;

export default DBreadcrumbsContainer;
