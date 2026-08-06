import Component from "@glimmer/component";
import { service } from "@ember/service";
import CategoriesOnly from "discourse/components/categories-only";

export default class CategoriesOnlyExample extends Component {
  @service site;

  <template><CategoriesOnly @categories={{this.site.categories}} /></template>
}
