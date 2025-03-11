import Component from "@ember/component";
import CategoriesOnly from "discourse/components/categories-only";

export default class CategoriesWithFeaturedTopics extends Component {
  <template>
    <CategoriesOnly @categories={{this.categories}} @showTopics="true" />
  </template>
}
