/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import CategoriesOnly from "discourse/components/categories-only";

@tagName("")
export default class CategoriesWithFeaturedTopics extends Component {
  <template>
    <div ...attributes>
      <CategoriesOnly @categories={{this.categories}} @showTopics="true" />
    </div>
  </template>
}
