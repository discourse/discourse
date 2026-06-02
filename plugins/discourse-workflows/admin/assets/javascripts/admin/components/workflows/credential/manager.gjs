import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";
import AdminTable from "../admin-table";
import EmptyState from "../empty-state";
import InUseDialog from "../in-use-dialog";
import PaginatedListManager from "../paginated-list-manager";
import CredentialModal from "./modal";

export default class CredentialsManager extends PaginatedListManager {
  get collectionKey() {
    return "credentials";
  }

  get basePath() {
    return "/admin/plugins/discourse-workflows/credentials";
  }

  @action
  addCredential() {
    this.modal.show(CredentialModal, {
      model: {
        credential: null,
        onSave: async (data) => {
          await ajax(this.apiUrl, {
            type: "POST",
            data,
          });
          await this.loadItems();
        },
      },
    });
  }

  @action
  editCredential(credential) {
    this.modal.show(CredentialModal, {
      model: {
        credential,
        onSave: async (data) => {
          await ajax(`${this.basePath}/${credential.id}.json`, {
            type: "PUT",
            data,
          });
          await this.loadItems();
        },
      },
    });
  }

  @action
  deleteCredential(credential) {
    this.dialog.deleteConfirm({
      message: i18n("discourse_workflows.credentials.delete_confirm", {
        name: credential.name,
      }),
      didConfirm: async () => {
        try {
          await ajax(`${this.basePath}/${credential.id}.json`, {
            type: "DELETE",
          });
          await this.loadItems();
        } catch (e) {
          const body = e.jqXHR?.responseJSON;
          if (body?.type === "credential_in_use") {
            this.dialog.alert({
              title: i18n("discourse_workflows.credentials.in_use_title"),
              bodyComponent: InUseDialog,
              bodyComponentModel: {
                description: i18n(
                  "discourse_workflows.credentials.in_use_description"
                ),
                workflows: body.referencing_workflows,
                close: () => this.dialog.cancel(),
              },
            });
          } else {
            popupAjaxError(e);
          }
        }
      },
    });
  }

  <template>
    <AdminTable
      @items={{this.items}}
      @isLoading={{this.isLoading}}
      @canLoadMore={{this.canLoadMore}}
      @loadMore={{this.loadMore}}
      @loadingMore={{this.loadingMore}}
    >
      <:empty>
        <EmptyState
          @emoji="locked_with_key"
          @title={{i18n
            "discourse_workflows.credentials.empty_title"
            username=this.currentUser.displayName
          }}
          @description={{i18n
            "discourse_workflows.credentials.empty_description"
          }}
          @buttonLabel="discourse_workflows.credentials.add_first"
          @onAction={{this.addCredential}}
        />
      </:empty>
      <:toolbar>
        <DButton
          @action={{this.addCredential}}
          @label="discourse_workflows.credentials.add"
          @icon="plus"
          class="btn-primary btn-small"
        />
      </:toolbar>
      <:head>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.credentials.name"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.credentials.type"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.credentials.created"
          }}</th>
        <th class="d-table__header-cell"></th>
      </:head>
      <:row as |credential|>
        <td class="d-table__cell --overview">
          <strong class="d-table__overview-name">{{credential.name}}</strong>
        </td>
        <td class="d-table__cell --detail">
          <div class="d-table__mobile-label">
            {{i18n "discourse_workflows.credentials.type"}}
          </div>
          {{credential.credential_type}}
        </td>
        <td class="d-table__cell --detail">
          <div class="d-table__mobile-label">
            {{i18n "discourse_workflows.credentials.created"}}
          </div>
          {{credential.created_at}}
        </td>
        <td class="d-table__cell --controls">
          <div class="d-table__cell-actions">
            <DButton
              @action={{fn this.editCredential credential}}
              @label="discourse_workflows.edit"
              @title="discourse_workflows.credentials.edit"
              class="btn-default btn-small"
            />
            <DMenu
              @identifier="workflows-credential-menu"
              @title={{i18n "discourse_workflows.more_options"}}
              @icon="ellipsis-vertical"
              @triggerClass="btn-default"
            >
              <:content>
                <DDropdownMenu as |dropdown|>
                  <dropdown.item>
                    <DButton
                      @action={{fn this.deleteCredential credential}}
                      @icon="trash-can"
                      @label="discourse_workflows.delete"
                      class="btn-danger"
                    />
                  </dropdown.item>
                </DDropdownMenu>
              </:content>
            </DMenu>
          </div>
        </td>
      </:row>
    </AdminTable>
  </template>
}
