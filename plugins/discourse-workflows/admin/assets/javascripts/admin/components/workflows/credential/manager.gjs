import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AdminTable from "../admin-table";
import EmptyState from "../empty-state";
import CredentialModal from "./modal";

export default class CredentialsManager extends Component {
  @service currentUser;
  @service dialog;
  @service modal;

  @tracked credentials = null;
  @tracked loadMoreUrl = null;
  @tracked totalRows = 0;
  @tracked loadingMore = false;

  constructor() {
    super(...arguments);
    this.loadCredentials();
  }

  async loadCredentials() {
    try {
      const result = await ajax(
        "/admin/plugins/discourse-workflows/credentials.json"
      );
      this.credentials = result.credentials;
      this.loadMoreUrl = result.meta?.load_more_credentials;
      this.totalRows =
        result.meta?.total_rows_credentials ?? result.credentials.length;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  get canLoadMore() {
    return this.credentials && this.credentials.length < this.totalRows;
  }

  get isLoading() {
    return this.credentials === null;
  }

  @action
  async loadMore() {
    if (!this.loadMoreUrl || !this.canLoadMore || this.loadingMore) {
      return;
    }

    this.loadingMore = true;
    try {
      const result = await ajax(this.loadMoreUrl);
      this.credentials = [...this.credentials, ...result.credentials];
      this.loadMoreUrl = result.meta?.load_more_credentials;
      this.totalRows = result.meta?.total_rows_credentials ?? this.totalRows;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loadingMore = false;
    }
  }

  @action
  addCredential() {
    this.modal.show(CredentialModal, {
      model: {
        credential: null,
        onSave: async (data) => {
          await ajax("/admin/plugins/discourse-workflows/credentials.json", {
            type: "POST",
            data,
          });
          await this.loadCredentials();
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
          await ajax(
            `/admin/plugins/discourse-workflows/credentials/${credential.id}.json`,
            { type: "PUT", data }
          );
          await this.loadCredentials();
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
          await ajax(
            `/admin/plugins/discourse-workflows/credentials/${credential.id}.json`,
            { type: "DELETE" }
          );
          await this.loadCredentials();
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  <template>
    <AdminTable
      @items={{this.credentials}}
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
