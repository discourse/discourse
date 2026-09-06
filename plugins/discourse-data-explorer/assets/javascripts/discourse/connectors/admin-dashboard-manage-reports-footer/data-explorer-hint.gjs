import { LinkTo } from "@ember/routing";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <LinkTo
    @route="adminPlugins.show.explorer.new"
    @model="discourse-data-explorer"
    class="de-cta"
  >
    <div class="de-cta__text">
      <span class="de-cta__title">
        {{i18n "data_explorer.manage_reports_hint.title"}}
      </span>
      <span class="de-cta__description">
        {{i18n "data_explorer.manage_reports_hint.description"}}
      </span>
    </div>
    {{dIcon "chevron-right" class="de-cta__chevron"}}
  </LinkTo>
</template>
