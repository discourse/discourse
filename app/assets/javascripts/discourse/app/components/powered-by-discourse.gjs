import icon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";

const PoweredByDiscourse = <template>
  {{! template-lint-disable link-rel-noopener }}
  <a
    class="powered-by-discourse"
    href="https://discourse.org/powered-by"
    target="_blank"
  >
    <span class="powered-by-discourse__content">
      <span class="powered-by-discourse__logo">
        {{icon "fab-discourse"}}
      </span>
      <span>{{i18n "powered_by_discourse"}}</span>
    </span>
  </a>
</template>;

export default PoweredByDiscourse;
