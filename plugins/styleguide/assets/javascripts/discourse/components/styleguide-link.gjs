import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import sectionTitle from "discourse/plugins/styleguide/discourse/helpers/section-title";

const StyleguideLink = <template>
  <LinkTo
    @route="styleguide.show"
    @models={{array @section.category @section.id}}
  >
    {{sectionTitle @section.id}}
  </LinkTo>
</template>;

export default StyleguideLink;
