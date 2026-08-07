import Component from "@glimmer/component";
import AdSlot, { slotContenders } from "./ad-slot";

export default class NestedRootAd extends Component {
  static shouldRender(args, context) {
    return (
      args.index &&
      slotContenders(
        context.site,
        context.siteSettings,
        "nested-roots-between",
        args.index
      ).length > 0
    );
  }

  <template>
    <div class="ad-connector ad-connector--nested-root">
      <AdSlot
        @placement="nested-roots-between"
        @category={{@topic.category.slug}}
        @indexNumber={{@index}}
      />
    </div>
  </template>
}
