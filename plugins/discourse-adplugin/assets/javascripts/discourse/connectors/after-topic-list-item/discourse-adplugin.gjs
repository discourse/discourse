/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import { slotContenders } from "discourse/plugins/discourse-adplugin/discourse/components/ad-slot";
import AdSlot from "../../components/ad-slot";

@tagName("")
export default class DiscourseAdplugin extends Component {
  static shouldRender(args, context) {
    return (
      args.index &&
      slotContenders(
        context.site,
        context.siteSettings,
        "topic-list-between",
        args.index
      ).length > 0
    );
  }

  <template>
    <tr class="after-topic-list-item-outlet discourse-adplugin" ...attributes>
      <AdSlot
        @placement="topic-list-between"
        @category={{this.category.slug}}
        @indexNumber={{this.index}}
        @childTagName="td"
      />
    </tr>
  </template>
}
