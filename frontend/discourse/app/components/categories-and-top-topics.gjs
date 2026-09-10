/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import CategoriesOnly from "discourse/components/categories-only";
import CategoriesTopicList from "discourse/components/categories-topic-list";
import PluginOutlet from "discourse/components/plugin-outlet";

@tagName("")
export default class CategoriesAndTopTopics extends Component {
  <template>
    <div class="categories-and-top" ...attributes>
      <div class="column categories">
        <CategoriesOnly @categories={{this.categories}} />
      </div>

      <div class="column">
        <CategoriesTopicList
          class="top-topic-list"
          @filter="top"
          @topics={{this.topics}}
        />
      </div>

      <PluginOutlet @connectorTagName="div" @name="extra-categories-column" />
    </div>
  </template>
}
