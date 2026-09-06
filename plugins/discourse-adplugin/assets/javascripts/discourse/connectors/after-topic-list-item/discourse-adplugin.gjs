import Component from "@glimmer/component";
import { slotContenders } from "discourse/plugins/discourse-adplugin/discourse/components/ad-slot";
import AdSlot from "../../components/ad-slot";

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
    <tr class="after-topic-list-item-outlet discourse-adplugin">
      <AdSlot
        @placement="topic-list-between"
        @category={{@outletArgs.category.slug}}
        @indexNumber={{@outletArgs.index}}
        @childTagName="td"
        @colspan="5"
      />
    </tr>
  </template>
}
