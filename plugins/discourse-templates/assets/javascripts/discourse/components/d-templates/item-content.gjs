import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import CookText from "discourse/components/cook-text";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

const ItemContent = <template>
  <div class="templates-content">
    <LinkTo
      class="template-item-source-link"
      @route="topic"
      @models={{array @template.slug @template.id}}
    >
      {{icon "crosshairs"}}
      {{i18n "templates.source"}}
    </LinkTo>
    <CookText @rawText={{@template.content}} />
  </div>
</template>;

export default ItemContent;
