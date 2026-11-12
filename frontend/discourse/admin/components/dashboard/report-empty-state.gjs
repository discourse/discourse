import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="db-report__empty">
    {{dIcon "chart-pie"}}
    <span>{{i18n "admin.dashboard.reports_section.no_data"}}</span>
  </div>
</template>
