import DButton from "discourse/ui-kit/d-button";
import DFlashMessage from "discourse/ui-kit/d-flash-message";
import { i18n } from "discourse-i18n";
import { nodeTypeLabel } from "../../../lib/workflows/node-types.js";
import { findNodeType } from "../../../lib/workflows/property-engine.js";

function baseNotice(deprecation, nodeTypes) {
  if (deprecation.replaced_by?.length) {
    const nodes = deprecation.replaced_by
      .map((identifier) =>
        nodeTypeLabel(findNodeType(nodeTypes, identifier) || identifier)
      )
      .join(", ");

    return i18n("discourse_workflows.node_deprecated.replaced_notice", {
      nodes,
    });
  }

  const changes = Object.entries(deprecation.changes || {})
    .map(([from, to]) => `${from} → ${to}`)
    .join(", ");

  return i18n("discourse_workflows.node_deprecated.notice", { changes });
}

export function deprecationMessage(deprecation, nodeTypes = null) {
  const notice = baseNotice(deprecation, nodeTypes);
  if (!deprecation.notice_key) {
    return notice;
  }

  return `${notice} ${i18n(deprecation.notice_key)}`;
}

const DeprecationNotice = <template>
  {{#if @deprecation}}
    <div class="workflows-deprecation-notice">
      <DFlashMessage
        @flash={{deprecationMessage @deprecation @nodeTypes}}
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
