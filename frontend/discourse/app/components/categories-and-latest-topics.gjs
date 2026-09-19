/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import CategoriesOnly from "discourse/components/categories-only";
import CategoriesTopicList from "discourse/components/categories-topic-list";
import PluginOutlet from "discourse/components/plugin-outlet";

@tagName("")
export default class CategoriesAndLatestTopics extends Component {
  <template>
    <div class="categories-and-latest" ...attributes>
      <div class="column categories">
        <CategoriesOnly @categories={{this.categories}} />
      </div>

      <div class="column">
        <CategoriesTopicList
          class="latest-topic-list"
          @filter="latest"
          @topics={{this.topics}}
        />
      </div>

      <PluginOutlet @connectorTagName="div" @name="extra-categories-column" />
    </div>
  </template>
}
