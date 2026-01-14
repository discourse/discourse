import { concat, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { i18n } from "discourse-i18n";

const GroupActivityFilter = <template>
  <li>
    <LinkTo
      @route={{concat "group.activity." @filter}}
      @query={{hash category_id=@categoryId}}
    >
      {{i18n (concat "groups." @filter)}}
    </LinkTo>
  </li>
</template>;

export default GroupActivityFilter;
