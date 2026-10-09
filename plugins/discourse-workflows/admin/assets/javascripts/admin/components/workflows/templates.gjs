import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq, not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DFilterControls from "discourse/ui-kit/d-filter-controls";
import DInterpolatedTranslation from "discourse/ui-kit/d-interpolated-translation";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { workflowFromTemplate } from "../../lib/workflows/template-workflow";

const SEARCHABLE_PROPS = ["name", "description"];

function requirementReason(requirement) {
  if (requirement.reason_key) {
    return i18n(requirement.reason_key);
  }

  return i18n("discourse_workflows.templates.missing_node", {
    node_type: requirement.node_type,
  });
}

export default class WorkflowsTemplates extends Component {
  @service router;

  @tracked creatingTemplateId = null;

  get workflowId() {
    return this.router.currentRoute?.queryParams?.workflow_id;
  }

  @action
  async useTemplate(template) {
    if (this.creatingTemplateId) {
      return;
    }

    this.creatingTemplateId = template.id;

    try {
      const fullTemplate = await ajax(
        `/admin/plugins/discourse-workflows/templates/${template.id}.json`
      );

      const workflow = workflowFromTemplate(fullTemplate.template);

      if (this.workflowId) {
        await ajax(
          `/admin/plugins/discourse-workflows/workflows/${this.workflowId}.json`,
          {
            type: "PUT",
            contentType: "application/json",
            data: JSON.stringify({ workflow }),
          }
        );

        this.router.transitionTo(
          "adminPlugins.show.discourse-workflows.show",
          this.workflowId
        );
        return;
      }

      const result = await ajax(
        "/admin/plugins/discourse-workflows/workflows.json",
        {
          type: "POST",
          contentType: "application/json",
          data: JSON.stringify({ workflow }),
        }
      );

      this.router.transitionTo(
        "adminPlugins.show.discourse-workflows.show",
        result.workflow.id
      );
    } catch (e) {
      popupAjaxError(e);
      this.creatingTemplateId = null;
    }
  }

  <template>
    <div class="workflows-templates">
      <DFilterControls
        @array={{@templates}}
        @inputPlaceholder={{i18n "discourse_workflows.templates.filter"}}
        @noResultsMessage={{i18n "discourse_workflows.templates.no_results"}}
        @searchableProps={{SEARCHABLE_PROPS}}
      >
        <:content as |filteredTemplates|>
          <table class="d-table">
            <tbody>
              {{#each filteredTemplates as |tmpl|}}
                <tr class="d-table__row">
                  <td class="d-table__cell --overview">
                    <div class="workflows-templates__title">
                      <strong
                        class="d-table__overview-name"
                      >{{tmpl.name}}</strong>
                      {{#each tmpl.plugins as |plugin|}}
                        <span class="d-table-badge">
                          <span
                            class="d-table-badge__content"
                          >{{plugin.name}}</span>
                        </span>
                      {{/each}}
                    </div>
                    <div class="workflows-templates__description">
                      {{tmpl.description}}
                    </div>
                    {{#each tmpl.plugins as |plugin|}}
                      {{#unless plugin.enabled}}
                        <div class="workflows-templates__requirement">
                          {{dIcon "triangle-exclamation"}}
                          <DInterpolatedTranslation
                            @key="discourse_workflows.templates.requires_plugin"
                            as |Placeholder|
                          >
                            <Placeholder @name="plugin">
                              <LinkTo
                                @query={{hash filter=plugin.name}}
                                @route="adminPlugins.index"
                              >
                                {{~i18n
                                  "discourse_workflows.templates.plugin_link"
                                  plugin=plugin.name
                                ~}}
                              </LinkTo>
                            </Placeholder>
                          </DInterpolatedTranslation>
                        </div>
                      {{/unless}}
                    {{/each}}
                    {{#each tmpl.missing_requirements as |requirement|}}
                      <div class="workflows-templates__requirement">
                        {{dIcon "triangle-exclamation"}}
                        <span>{{requirementReason requirement}}</span>
                      </div>
                    {{/each}}
                  </td>
                  <td class="d-table__cell --controls">
                    <DButton
                      class="btn-default btn-small"
                      @action={{fn this.useTemplate tmpl}}
                      @disabled={{or
                        this.creatingTemplateId
                        (not tmpl.available)
                      }}
                      @isLoading={{eq this.creatingTemplateId tmpl.id}}
                      @label="discourse_workflows.templates.use_template"
                    />
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        </:content>
      </DFilterControls>
    </div>
  </template>
}
