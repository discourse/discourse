import { concat } from "@ember/helper";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const ICONS = {
  passed: "circle-check",
  failed: "circle-xmark",
  could_not_run: "ban",
  run_again: "arrow-rotate-left",
  running: "arrows-rotate",
  not_run: "circle",
};

function statusIcon(status) {
  return ICONS[status] || ICONS.not_run;
}

export default <template>
  <span
    class={{dConcatClass "workflows-test-status" (concat "--" @status)}}
    ...attributes
  >
    {{dIcon (statusIcon @status)}}
    {{i18n (concat "discourse_workflows.tests.statuses." @status)}}
  </span>
</template>
