import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AdminTable from "../admin-table";
import CrudManager from "../crud-manager";
import EmptyState from "../empty-state";
import InUseDialog from "../in-use-dialog";
import CredentialModal from "./modal";

export default class CredentialsManager extends CrudManager {
  get itemsKey() {
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
          @emoji="🔐"
          @title={{i18n
            "discourse_workflows.credentials.empty_title"
            username=this.currentUser.username
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
        <th>{{i18n "discourse_workflows.credentials.name"}}</th>
        <th>{{i18n "discourse_workflows.credentials.type"}}</th>
        <th>{{i18n "discourse_workflows.credentials.created"}}</th>
        <th></th>
      </:head>
      <:row as |credential|>
        <td>{{credential.name}}</td>
        <td>{{credential.credential_type}}</td>
        <td>{{credential.created_at}}</td>
        <td class="workflows-admin-table__actions">
          <DButton
            @action={{fn this.editCredential credential}}
            @icon="pencil"
            class="btn-flat btn-small"
          />
          <DButton
            @action={{fn this.deleteCredential credential}}
            @icon="trash-can"
            class="btn-flat btn-small btn-danger"
          />
        </td>
      </:row>
    </AdminTable>
  </template>
}
