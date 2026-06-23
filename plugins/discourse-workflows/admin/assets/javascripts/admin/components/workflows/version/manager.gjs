import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { userPath } from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import { i18n } from "discourse-i18n";
import AdminTable from "../admin-table";
import EmptyState from "../empty-state";
import PaginatedListManager from "../paginated-list-manager";

export default class VersionsManager extends PaginatedListManager {
  @service router;
  @service store;
  @service toasts;

  get collectionKey() {
    return "versions";
  }

  get basePath() {
    return `/admin/plugins/discourse-workflows/workflows/${this.args.workflow.id}/versions`;
  }

  @action
  revert(version) {
    this.dialog.yesNoConfirm({
      message: i18n("discourse_workflows.versions.revert_confirm", {
        version: version.version_number,
      }),
      didConfirm: async () => {
        try {
          await ajax(`${this.basePath}/${version.version_id}/restore.json`, {
            type: "POST",
          });
          // Refresh the cached workflow record so the editor reflects the
          // restored draft when we transition back to it.
          await this.store.find(
            "discourse-workflows-workflow",
            this.args.workflow.id
          );
          this.toasts.success({
            duration: "short",
            data: {
              message: i18n("discourse_workflows.versions.reverted", {
                version: version.version_number,
              }),
            },
          });
          this.router.transitionTo(
            "adminPlugins.show.discourse-workflows.show.index",
            this.args.workflow.id
          );
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  <template>
    <AdminTable
      @items={{this.items}}
      @itemKey="version_id"
      @isLoading={{this.isLoading}}
      @canLoadMore={{this.canLoadMore}}
      @loadMore={{this.loadMore}}
      @loadingMore={{this.loadingMore}}
      class="workflows-versions-manager"
    >
      <:empty>
        <EmptyState
          @emoji="floppy_disk"
          @title={{i18n "discourse_workflows.versions.empty_title"}}
          @description={{i18n "discourse_workflows.versions.empty_description"}}
        />
      </:empty>
      <:head>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.versions.version"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.versions.author"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.versions.changed_at"
          }}</th>
        <th class="d-table__header-cell"></th>
      </:head>
      <:row as |version|>
        <td class="d-table__cell --overview">
          <strong class="d-table__overview-name">{{i18n
              "discourse_workflows.versions.version_number"
              number=version.version_number
            }}</strong>
          {{#if version.is_current}}
            <span class="workflows-versions__badge --current">{{i18n
                "discourse_workflows.versions.current"
              }}</span>
          {{/if}}
          {{#if version.is_active}}
            <span class="workflows-versions__badge --live">{{i18n
                "discourse_workflows.versions.live"
              }}</span>
          {{/if}}
        </td>
        <td class="d-table__cell --detail">
          <div class="d-table__mobile-label">
            {{i18n "discourse_workflows.versions.author"}}
          </div>
          {{#if version.created_by}}
            <a
              href={{userPath version.created_by.username}}
              class="workflows-versions__author"
            >
              {{dAvatar version.created_by imageSize="tiny"}}
              <span>{{version.created_by.username}}</span>
            </a>
          {{/if}}
        </td>
        <td class="d-table__cell --detail">
          <div class="d-table__mobile-label">
            {{i18n "discourse_workflows.versions.changed_at"}}
          </div>
          {{dFormatDate version.created_at format="medium"}}
        </td>
        <td class="d-table__cell --controls">
          <div class="d-table__cell-actions">
            {{#unless version.is_current}}
              <DButton
                @action={{fn this.revert version}}
                @label="discourse_workflows.versions.revert"
                @icon="arrow-rotate-left"
                class="btn-default btn-small workflows-versions__revert"
              />
            {{/unless}}
          </div>
        </td>
      </:row>
    </AdminTable>
  </template>
}
