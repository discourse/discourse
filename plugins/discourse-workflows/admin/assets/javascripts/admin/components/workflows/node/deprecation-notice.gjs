import DButton from "discourse/ui-kit/d-button";
import DFlashMessage from "discourse/ui-kit/d-flash-message";
import { i18n } from "discourse-i18n";

export function deprecationMessage(deprecation) {
  const changes = Object.entries(deprecation.changes || {})
    .map(([from, to]) => `${from} → ${to}`)
    .join(", ");

  const notice = i18n("discourse_workflows.node_deprecated.notice", {
    changes,
  });
  if (!deprecation.notice_key) {
    return notice;
  }

  return `${notice} ${i18n(deprecation.notice_key)}`;
}

const DeprecationNotice = <template>
  {{#if @deprecation}}
    <div class="workflows-deprecation-notice">
      <DFlashMessage
        @flash={{deprecationMessage @deprecation}}
        @type="warning"
      />
      <DButton
        class="btn-small workflows-deprecation-notice__upgrade"
        @action={{@onUpgrade}}
        @label="discourse_workflows.node_deprecated.upgrade"
      />
    </div>
  {{/if}}
</template>;

export default DeprecationNotice;
