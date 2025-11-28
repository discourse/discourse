import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import IpLookupAccountsTable from "discourse/admin/components/ip-lookup-accounts-table";
import AdminUser from "discourse/admin/models/admin-user";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

const MAX_ACCOUNTS_TO_DELETE = 50;

export default class ReviewableIpLookup extends Component {
  @service currentUser;
  @service modal;
  @service dialog;

  @tracked location;
  @tracked otherAccounts;
  @tracked loading = true;
  @tracked otherAccountsLoading = false;
  @tracked totalOthersWithSameIP;
  @tracked ipAddress;

  constructor() {
    super(...arguments);
    this.loadIpData();
  }

  get showIpLookup() {
    return this.currentUser.staff && this.target;
  }

  get target() {
    return this.args.reviewable.type === "ReviewableUser"
      ? this.args.reviewable.target_user?.id
      : this.args.reviewable.target_created_by?.id;
  }

  get otherAccountsToDelete() {
    return Math.min(MAX_ACCOUNTS_TO_DELETE, this.totalOthersWithSameIP || 0);
  }

  get canDeleteOtherAccounts() {
    return this.totalOthersWithSameIP && !this.otherAccountsLoading;
  }

  get queryData() {
    return {
      ip: this.ipAddress,
      exclude: this.target,
      order: "trust_level DESC",
    };
  }

  @action
  async loadIpData() {
    if (!this.target) {
      this.loading = false;
      return;
    }

    try {
      const userInfo = await AdminUser.find(this.target);
      this.ipAddress = userInfo.ip_address;

      if (this.ipAddress) {
        this.location = await ajax("/admin/users/ip-info", {
          data: { ip: this.ipAddress },
        });

        const result = await ajax("/admin/users/total-others-with-same-ip", {
          data: this.queryData,
        });
        this.totalOthersWithSameIP = result.total;
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  async loadOtherAccounts() {
    if (this.otherAccounts || this.otherAccountsLoading) {
      return;
    }

    this.otherAccountsLoading = true;

    try {
      this.otherAccounts = await AdminUser.findAll("active", this.queryData);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.otherAccountsLoading = false;
    }
  }

  @action
  async deleteOtherAccounts() {
    this.dialog.yesNoConfirm({
      message: i18n("ip_lookup.confirm_delete_other_accounts"),
      didConfirm: async () => {
        this.otherAccounts = null;
        this.otherAccountsLoading = true;
        this.totalOthersWithSameIP = null;

        try {
          await ajax("/admin/users/delete-others-with-same-ip.json", {
            type: "DELETE",
            data: this.queryData,
          });
          this.modal.close();
        } catch (err) {
          popupAjaxError(err);
        } finally {
          this.otherAccountsLoading = false;
        }
      },
    });
  }

  @action
  async showOtherAccountsModal() {
    await this.loadOtherAccounts();

    this.modal.show(OtherAccountsModal, {
      model: {
        otherAccounts: this.otherAccounts,
        totalOthersWithSameIP: this.totalOthersWithSameIP,
        otherAccountsLoading: this.otherAccountsLoading,
        otherAccountsToDelete: this.otherAccountsToDelete,
        canDeleteOtherAccounts: this.canDeleteOtherAccounts,
        deleteOtherAccounts: this.deleteOtherAccounts,
      },
    });
  }

  <template>
    {{#if this.showIpLookup}}
      {{#if this.loading}}
        <ConditionalLoadingSpinner @size="small" @condition={{this.loading}} />
      {{else if this.location}}
        <div class="reviewable-ip-lookup">
          <div class="review-insight__item">
            <div class="review-insight__content">
              <div class="review-insight__label">
                {{i18n "ip_lookup.title"}}
                <span class="ip-lookup-powered-by">
                  ({{htmlSafe (i18n "ip_lookup.powered_by")}})
                </span>
              </div>
              <div class="review-insight__description">
                {{#if this.location.hostname}}
                  {{i18n "ip_lookup.hostname"}}:
                  {{this.location.hostname}},
                {{/if}}
                {{i18n "ip_lookup.location"}}:
                {{#if this.location.location}}
                  <a
                    href="https://maps.google.com/maps?q={{this.location.latitude}},{{this.location.longitude}}"
                    rel="noopener noreferrer"
                    target="_blank"
                  >{{this.location.location}}</a>
                {{else}}
                  {{i18n "ip_lookup.location_not_found"}}
                {{/if}}
                {{#if this.location.organization}}
                  ,
                  {{i18n "ip_lookup.organisation"}}:
                  {{this.location.organization}}
                {{/if}}
              </div>
              {{#if this.totalOthersWithSameIP}}
                <div class="review-insight__description">
                  <button
                    type="button"
                    {{on "click" this.showOtherAccountsModal}}
                    class="btn-link ip-lookup-other-accounts-link"
                  >
                    {{i18n
                      "ip_lookup.other_accounts_with_ip"
                      count=this.totalOthersWithSameIP
                    }}
                  </button>
                </div>
              {{/if}}
            </div>
          </div>
        </div>
      {{/if}}
    {{/if}}
  </template>
}

const OtherAccountsModal = <template>
  <DModal
    @title={{i18n
      "ip_lookup.other_accounts_with_ip"
      count=@model.totalOthersWithSameIP
    }}
    @closeModal={{@closeModal}}
    class="ip-lookup-other-accounts-modal"
  >
    <:body>
      {{#if @model.otherAccountsLoading}}
        <ConditionalLoadingSpinner
          @size="small"
          @condition={{@model.otherAccountsLoading}}
        />
      {{else if @model.otherAccounts}}
        <IpLookupAccountsTable @accounts={{@model.otherAccounts}} />
      {{/if}}
    </:body>
    <:footer>
      {{#if @model.canDeleteOtherAccounts}}
        <DButton
          @action={{@model.deleteOtherAccounts}}
          @icon="triangle-exclamation"
          @translatedLabel={{i18n
            "ip_lookup.delete_other_accounts"
            count=@model.otherAccountsToDelete
          }}
          class="btn-danger"
        />
      {{/if}}
    </:footer>
  </DModal>
</template>;
