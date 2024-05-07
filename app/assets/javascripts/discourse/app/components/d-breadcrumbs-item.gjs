import BreadcrumbsItem from "discourse/components/breadcrumbs-item";

const DBreadcrumbsItem = <template>
  <BreadcrumbsItem as |linkClass|>
    {{yield linkClass}}
  </BreadcrumbsItem>
</template>;

export default DBreadcrumbsItem;
