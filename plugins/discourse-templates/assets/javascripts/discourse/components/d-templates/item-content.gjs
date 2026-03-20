import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import DCookText from "discourse/ui-kit/d-cook-text";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const ItemContent = <template>
  <div class="templates-content">
    <LinkTo
      class="template-item-source-link"
      @route="topic"
      @models={{array @template.slug @template.id}}
    >
      {{dIcon "crosshairs"}}
      {{i18n "templates.source"}}
    </LinkTo>
    <DCookText @rawText={{@template.content}} />
  </div>
</template>;

export default ItemContent;
