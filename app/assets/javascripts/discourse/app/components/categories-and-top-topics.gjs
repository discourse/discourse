import Component from "@ember/component";
import { classNames } from "@ember-decorators/component";

@classNames("categories-and-top")
export default class CategoriesAndTopTopics extends Component {}

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