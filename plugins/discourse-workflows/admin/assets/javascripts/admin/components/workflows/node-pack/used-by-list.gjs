import { LinkTo } from "@ember/routing";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @workflows.length}}
    <div class="workflows-node-packs__table-wrap">
      <table class="d-table workflows-node-packs__table">
        <thead class="d-table__header">
          <tr class="d-table__row">
            <th class="d-table__header-cell">{{i18n
                "discourse_workflows.node_packs.workflow"
              }}</th>
            <th class="d-table__header-cell">{{i18n
                "discourse_workflows.node_packs.version_status"
              }}</th>
            <th class="d-table__header-cell">{{i18n
                "discourse_workflows.node_packs.nodes_used"
              }}</th>
          </tr>
        </thead>
        <tbody class="d-table__body">
          {{#each @workflows as |workflow|}}
            <tr class="d-table__row">
              <td class="d-table__cell --overview">
                <LinkTo
                  class="d-table__overview-link"
                  @model={{workflow.id}}
                  @route="adminPlugins.show.discourse-workflows.show"
                >
                  <strong
                    class="d-table__overview-name"
                  >{{workflow.name}}</strong>
                </LinkTo>
              </td>
              <td class="d-table__cell --detail">
                <div class="d-table__mobile-label">{{i18n
                    "discourse_workflows.node_packs.version_status"
                  }}</div>
                <span class="badge-notification --low">
                  {{if
                    workflow.published
                    (i18n "discourse_workflows.published")
                    (i18n "discourse_workflows.node_packs.draft")
                  }}
                </span>
              </td>
              <td class="d-table__cell --detail">
                <div class="d-table__mobile-label">{{i18n
                    "discourse_workflows.node_packs.nodes_used"
                  }}</div>
                {{workflow.node_ids.length}}
              </td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    </div>
  {{else}}
    <p class="workflows-node-packs__empty-section">{{i18n
        "discourse_workflows.node_packs.not_used"
      }}</p>
  {{/if}}
</template>
