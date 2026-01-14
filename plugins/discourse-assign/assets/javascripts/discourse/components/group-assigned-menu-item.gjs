import { LinkTo } from "@ember/routing";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

const GroupAssignedMenuItem = <template>
  <LinkTo @route="group.assigned">
    {{icon "group-plus" class="glyph"}}{{i18n "discourse_assign.assigned"}}
    ({{@group.assignment_count}})
  </LinkTo>
</template>;

export default GroupAssignedMenuItem;
