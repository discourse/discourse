import { concat} from "@ember/helper";
import { htmlSafe } from "@ember/template";
import { i18n } from "discourse-i18n";

  <template>
    {{log (i18n (concat "admin.site_settings.job_status." @status))}}
    {{#if @status}}
      <div class="desc">{{htmlSafe (i18n (concat "admin.site_settings.job_status." @status))}}</div>
    {{/if}}
  </template>
