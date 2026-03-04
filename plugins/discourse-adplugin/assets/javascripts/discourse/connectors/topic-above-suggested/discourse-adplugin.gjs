/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import AdSlot from "../../components/ad-slot";

@tagName("")
export default class DiscourseAdplugin extends Component {
  <template>
    <div class="topic-above-suggested-outlet discourse-adplugin" ...attributes>
      <AdSlot
        @placement="topic-above-suggested"
        @category={{this.model.category.slug}}
      />
    </div>
  </template>
}
