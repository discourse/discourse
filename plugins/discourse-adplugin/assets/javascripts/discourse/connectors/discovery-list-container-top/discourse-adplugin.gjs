import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import AdSlot from "../../components/ad-slot";

@tagName("span")
@classNames("discovery-list-container-top-outlet", "discourse-adplugin")
export default class DiscourseAdplugin extends Component {
  <template>
    <AdSlot @placement="topic-list-top" @category={{this.category.slug}} />
  </template>
}
