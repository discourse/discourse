import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import CategoriesOnly from "discourse/components/categories-only";
const CategoriesList = <template><StyleguideExample @title="<CategoriesOnly>">
  <CategoriesOnly @categories={{@dummy.categories}} />
</StyleguideExample></template>;
export default CategoriesList;