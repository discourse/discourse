import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import LoadMore from "discourse/components/load-more";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import EmptyState from "../empty-state";
import VariableModal from "./modal";

export default class VariablesManager extends Component {
  @service currentUser;
  @service dialog;
  @service modal;

  @tracked variables = null;
  @tracked loadMoreUrl = null;
  @tracked totalRows = 0;
  @tracked loadingMore = false;

  constructor() {
    super(...arguments);
    this.loadVariables();
  }

  async loadVariables() {
    try {
      const result = await ajax(
        "/admin/plugins/discourse-workflows/variables.json"
      );
      this.variables = result.variables;
      this.loadMoreUrl = result.meta?.load_more_variables;
      this.totalRows =
        result.meta?.total_rows_variables ?? result.variables.length;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  get canLoadMore() {
    return this.variables && this.variables.length < this.totalRows;
  }

  @action
  async loadMore() {
    if (!this.loadMoreUrl || !this.canLoadMore || this.loadingMore) {
      return;
    }

    this.loadingMore = true;
    try {
      const result = await ajax(this.loadMoreUrl);
      this.variables = [...this.variables, ...result.variables];
      this.loadMoreUrl = result.meta?.load_more_variables;
      this.totalRows = result.meta?.total_rows_variables ?? this.totalRows;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loadingMore = false;
    }
  }

  @action
  addVariable() {
    this.modal.show(VariableModal, {
      model: {
        variable: null,
        onSave: async (data) => {
          await ajax("/admin/plugins/discourse-workflows/variables.json", {
            type: "POST",
            data,
          });
          await this.loadVariables();
        },
      },
    });
  }

  @action
  editVariable(variable) {
    this.modal.show(VariableModal, {
      model: {
        variable,
        onSave: async (data) => {
          await ajax(
            `/admin/plugins/discourse-workflows/variables/${variable.id}.json`,
            {
              type: "PUT",
              data,
            }
          );
          await this.loadVariables();
        },
      },
    });
  }

  @action
  deleteVariable(variable) {
    this.dialog.deleteConfirm({
      message: i18n("discourse_workflows.variables.delete_confirm", {
        key: variable.key,
      }),
      didConfirm: async () => {
        try {
          await ajax(
            `/admin/plugins/discourse-workflows/variables/${variable.id}.json`,
            {
              type: "DELETE",
            }
          );
          await this.loadVariables();
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  @action
  async copySyntax(key) {
    await clipboardCopy(`$vars.${key}`);
  }

  get isLoading() {
    return this.variables === null;
  }

  <template>
    <div class="workflows-variables-manager">
      <ConditionalLoadingSpinner @condition={{this.isLoading}}>
        {{#if this.variables.length}}
          <div class="workflows-variables-manager__toolbar">
            <DButton
              @action={{this.addVariable}}
              @label="discourse_workflows.variables.add"
              @icon="plus"
              class="btn-primary btn-small"
            />
          </div>

          <LoadMore @action={{this.loadMore}} @enabled={{this.canLoadMore}}>
            <table class="workflows-variables-manager__table">
              <thead>
                <tr>
                  <th>{{i18n "discourse_workflows.variables.key"}}</th>
                  <th>{{i18n "discourse_workflows.variables.value"}}</th>
                  <th>{{i18n "discourse_workflows.variables.usage_syntax"}}</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {{#each this.variables as |variable|}}
                  <tr>
                    <td>{{variable.key}}</td>
                    <td>{{variable.value}}</td>
                    <td>
                      <DButton
                        @action={{fn this.copySyntax variable.key}}
                        @translatedLabel={{concat "$vars." variable.key}}
                        @icon="copy"
                        @title="discourse_workflows.variables.copy_syntax"
                        class="btn-flat btn-small"
                      />
                    </td>
                    <td class="workflows-variables-manager__actions">
                      <DButton
                        @action={{fn this.editVariable variable}}
                        @icon="pencil"
                        class="btn-flat btn-small"
                      />
                      <DButton
                        @action={{fn this.deleteVariable variable}}
                        @icon="trash-can"
                        class="btn-flat btn-small btn-danger"
                      />
                    </td>
                  </tr>
                {{/each}}
              </tbody>
            </table>
            <ConditionalLoadingSpinner @condition={{this.loadingMore}} />
          </LoadMore>
        {{else}}
          <EmptyState
            @emoji="👋"
            @title={{i18n
              "discourse_workflows.variables.empty_title"
              username=this.currentUser.username
            }}
            @description={{i18n
              "discourse_workflows.variables.empty_description"
            }}
            @buttonLabel="discourse_workflows.variables.add_first"
            @onAction={{this.addVariable}}
          />
        {{/if}}
      </ConditionalLoadingSpinner>
    </div>
  </template>
}
