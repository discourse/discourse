import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="db-report__error" role="alert">
    {{dIcon "triangle-exclamation"}}
    <span>{{i18n "admin.dashboard.reports_section.report_error"}}</span>
  </div>
</template>
