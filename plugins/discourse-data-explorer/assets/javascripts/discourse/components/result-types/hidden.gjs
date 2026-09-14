import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const Hidden = <template>
  <span class="query-result-hidden" title={{i18n "explorer.hidden_relation"}}>
    {{dIcon "lock"}}
    {{@textValue}}
  </span>
</template>;

export default Hidden;
