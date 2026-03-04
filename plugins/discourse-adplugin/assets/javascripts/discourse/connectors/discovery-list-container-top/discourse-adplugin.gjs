/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import AdSlot from "../../components/ad-slot";

@tagName("")
export default class DiscourseAdplugin extends Component {
  <template>
    <span
      class="discovery-list-container-top-outlet discourse-adplugin"
      ...attributes
    >
      <AdSlot @placement="topic-list-top" @category={{this.category.slug}} />
    </span>
  </template>
}
