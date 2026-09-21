import { LinkTo } from "@ember/routing";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @nodes.length}}
    <div class="workflows-node-packs__table-wrap">
      <table class="d-table workflows-node-packs__table">
        <thead class="d-table__header">
          <tr class="d-table__row">
            <th class="d-table__header-cell">{{i18n
                "discourse_workflows.node_packs.node"
              }}</th>
            <th class="d-table__header-cell">{{i18n
                "discourse_workflows.node_packs.identifier"
              }}</th>
            <th class="d-table__header-cell">{{i18n
                "discourse_workflows.node_packs.request"
              }}</th>
            <th class="d-table__header-cell">{{i18n
                "discourse_workflows.node_packs.credential"
              }}</th>
            <th class="d-table__header-cell">{{i18n
                "discourse_workflows.node_packs.used_by"
              }}</th>
          </tr>
        </thead>
        <tbody class="d-table__body">
          {{#each @nodes as |node|}}
            <tr class="d-table__row">
              <td class="d-table__cell --overview">
                <strong class="d-table__overview-name">{{node.label}}</strong>
                {{#if node.subtitle}}
                  <span
                    class="workflows-node-packs__secondary"
                  >{{node.subtitle}}</span>
                {{/if}}
                {{#if node.retired}}
                  <span
                    class="badge-notification --low workflows-node-packs__badge"
                  >
                    {{i18n "discourse_workflows.node_packs.retired"}}
                  </span>
                {{/if}}
                {{#if node.docs_url}}
                  <a
                    class="workflows-node-packs__docs-link"
                    href={{node.docs_url}}
                    rel="noopener noreferrer"
                    target="_blank"
                  >{{i18n "discourse_workflows.node_packs.documentation"}} ↗</a>
                {{/if}}
              </td>
              <td class="d-table__cell --detail">
                <div class="d-table__mobile-label">{{i18n
                    "discourse_workflows.node_packs.identifier"
                  }}</div>
                <code>{{node.identifier}}</code>
                <span
                  class="workflows-node-packs__secondary"
                >v{{node.version}}</span>
              </td>
              <td class="d-table__cell --detail">
                <div class="d-table__mobile-label">{{i18n
                    "discourse_workflows.node_packs.request"
                  }}</div>
                <strong>{{node.request.method}}</strong>
                <span
                  class="workflows-node-packs__request-url"
                >{{node.request.url}}</span>
              </td>
              <td class="d-table__cell --detail">
                <div class="d-table__mobile-label">{{i18n
                    "discourse_workflows.node_packs.credential"
                  }}</div>
                {{#if node.credential}}
                  {{node.credential}}
                {{else}}
                  {{i18n "discourse_workflows.node_packs.none"}}
                {{/if}}
              </td>
              <td class="d-table__cell --detail">
                <div class="d-table__mobile-label">{{i18n
                    "discourse_workflows.node_packs.used_by"
                  }}</div>
                {{node.used_by_count}}
              </td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    </div>
  {{else}}
    <p class="workflows-node-packs__empty-section">{{i18n
        "discourse_workflows.node_packs.no_nodes"
      }}</p>
  {{/if}}

  <p class="workflows-node-packs__workflow-link">
    <LinkTo @route="adminPlugins.show.discourse-workflows.index">
      {{i18n "discourse_workflows.node_packs.open_workflows"}}
    </LinkTo>
  </p>
</template>
