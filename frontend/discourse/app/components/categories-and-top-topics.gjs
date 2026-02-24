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
          @topics={{this.topics}}
          @filter="top"
          class="top-topic-list"
        />
      </div>

      <PluginOutlet @name="extra-categories-column" @connectorTagName="div" />
    </div>
  </template>
}
