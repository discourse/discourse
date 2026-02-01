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
          @topics={{this.topics}}
          @filter="latest"
          class="latest-topic-list"
        />
      </div>

      <PluginOutlet @name="extra-categories-column" @connectorTagName="div" />
    </div>
  </template>
}
