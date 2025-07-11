import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import AdSlot from "../../components/ad-slot";

@tagName("div")
@classNames("topic-above-suggested-outlet", "discourse-adplugin")
export default class DiscourseAdplugin extends Component {
  <template>
    <AdSlot
      @placement="topic-above-suggested"
      @category={{this.model.category.slug}}
    />
  </template>
}
