import Component from "@ember/component";
import { classNames } from "@ember-decorators/component";

@classNames("categories-and-latest")
export default class CategoriesAndLatestTopics extends Component {}
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