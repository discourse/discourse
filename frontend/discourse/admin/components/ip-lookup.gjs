import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { gt } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import avatar from "discourse/helpers/avatar";
import loadingSpinner from "discourse/helpers/loading-spinner";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import AdminUser from "admin/models/admin-user";
import DMenu from "float-kit/components/d-menu";

const MAX_ACCOUNTS_TO_DELETE = 50;

export default class IpLookup extends Component {
  @service dialog;
  @service site;
  @service toasts;

  @tracked location;
  @tracked otherAccounts;
  @tracked loading = false;
  @tracked otherAccountsLoading = false;
  @tracked totalOthersWithSameIP;
  @tracked ipToLookup = this.args.ip;

  get otherAccountsToDelete() {
    const otherAccountsLength = this.otherAccounts?.length || 0;
    const totalOthers = this.totalOthersWithSameIP || 0;
    const total = Math.min(MAX_ACCOUNTS_TO_DELETE, totalOthers);
    const visible = Math.min(MAX_ACCOUNTS_TO_DELETE, otherAccountsLength);
    return Math.max(visible, total);
  }

  @action
  async lookup() {
    this.loading = true;
    try {
      if (this.args.ip === "adminLookup") {
        try {
          const userInfo = await AdminUser.find(this.args.userId);
          this.ipToLookup = userInfo.ip_address;
        } catch (err) {
          popupAjaxError(err);
          return;
        }
      }

      if (!this.location && this.ipToLookup) {
        this.location = await ajax("/admin/users/ip-info", {
          data: { ip: this.ipToLookup },
        });
      }

      if (!this.otherAccounts && this.ipToLookup) {
        this.otherAccountsLoading = true;

        const data = {
          ip: this.ipToLookup,
          exclude: this.args.userId,
          order: "trust_level DESC",
        };

        const result = await ajax("/admin/users/total-others-with-same-ip", {
          data,
        });
        this.totalOthersWithSameIP = result.total;

        this.otherAccounts = await AdminUser.findAll("active", data);
        this.otherAccountsLoading = false;
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  async copy() {
    const { location } = this;
    let text = `IP: ${this.ipToLookup}`;

    if (location) {
      if (location.hostname) {
        text += "\n" + `${i18n("ip_lookup.hostname")}: ${location.hostname}`;
      }

      text += "\n" + i18n("ip_lookup.location");
      text += location.location
        ? `: ${location.location}`
        : `: ${i18n("ip_lookup.location_not_found")}`;

      if (location.organization) {
        text +=
          "\n" + `${i18n("ip_lookup.organisation")}: ${location.organization}`;
      }
    }

    try {
      await clipboardCopy(text.trim());
      this.toasts.success({
        duration: 3000,
        data: {
          message: i18n("ip_lookup.copied"),
        },
      });
    } catch (err) {
      popupAjaxError(err);
    }
  }

  @action
  deleteOtherAccounts() {
    this.dialog.yesNoConfirm({
      message: i18n("ip_lookup.confirm_delete_other_accounts"),
      didConfirm: async () => {
        this.otherAccounts = null;
        this.otherAccountsLoading = true;
        this.totalOthersWithSameIP = null;

        try {
          await ajax("/admin/users/delete-others-with-same-ip.json", {
            type: "DELETE",
            data: {
              ip: this.ipToLookup,
              exclude: this.args.userId,
              order: "trust_level DESC",
            },
          });
        } catch (err) {
          popupAjaxError(err);
        }
      },
    });
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  close() {
    this.dMenu.close();
  }

  <template>
    <DMenu
      @identifier="ip-lookup"
      @label={{i18n "admin.user.ip_lookup"}}
      @icon="globe"
      @onShow={{this.lookup}}
      @modalForMobile={{true}}
      @onRegisterApi={{this.onRegisterApi}}
      @isLoading={{this.loading}}
      @class="btn-default"
    >
      <:content>
        <div class="location-box">
          <div class="location-box__content">
            <div class="title">
              {{i18n "ip_lookup.title"}}
              <div class="location-box__controls">
                <DButton
                  @action={{this.copy}}
                  @icon="copy"
                  class="btn-transparent"
                />
                {{#if this.site.mobileView}}
                  <DButton
                    @action={{this.close}}
                    @icon="xmark"
                    class="btn-transparent"
                  />
                {{/if}}

              </div>
            </div>
            <dl>
              {{#if this.location}}
                {{#if this.location.hostname}}
                  <dt>{{i18n "ip_lookup.hostname"}}</dt>
                  <dd>{{this.location.hostname}}</dd>
                {{/if}}

                <dt>{{i18n "ip_lookup.location"}}</dt>
                <dd>
                  {{#if this.location.location}}
                    <a
                      href="https://maps.google.com/maps?q={{this.location.latitude}},{{this.location.longitude}}"
                      rel="noopener noreferrer"
                      target="_blank"
                    >
                      {{this.location.location}}
                    </a>
                  {{else}}
                    {{i18n "ip_lookup.location_not_found"}}
                  {{/if}}
                </dd>

                {{#if this.location.organization}}
                  <dt>{{i18n "ip_lookup.organisation"}}</dt>
                  <dd>{{this.location.organization}}</dd>
                {{/if}}
              {{else}}
                {{loadingSpinner size="small"}}
              {{/if}}

              <dt class="other-accounts">
                {{i18n "ip_lookup.other_accounts"}}
                <span
                  class="count
                    {{if (gt this.totalOthersWithSameIP 0) '--nonzero'}}"
                >
                  {{this.totalOthersWithSameIP}}
                </span>
                {{#if this.otherAccounts}}
                  <DButton
                    @action={{this.deleteOtherAccounts}}
                    @icon="triangle-exclamation"
                    @translatedLabel={{i18n
                      "ip_lookup.delete_other_accounts"
                      count=this.otherAccountsToDelete
                    }}
                    class="btn-danger pull-right"
                  />
                {{/if}}
              </dt>

              <ConditionalLoadingSpinner
                @size="small"
                @condition={{this.otherAccountsLoading}}
              >
                {{#if this.otherAccounts}}
                  <dd class="other-accounts">
                    <table class="table table-condensed table-hover">
                      <thead>
                        <tr>
                          <th>{{i18n "ip_lookup.username"}}</th>
                          <th>{{i18n "ip_lookup.trust_level"}}</th>
                          <th>{{i18n "ip_lookup.read_time"}}</th>
                          <th>{{i18n "ip_lookup.topics_entered"}}</th>
                          <th>{{i18n "ip_lookup.post_count"}}</th>
                        </tr>
                      </thead>
                      <tbody>
                        {{#each this.otherAccounts as |account|}}
                          <tr>
                            <td class="user">
                              <LinkTo @route="adminUser" @model={{account}}>
                                {{avatar account imageSize="tiny"}}
                                <span>{{account.username}}</span>
                              </LinkTo>
                            </td>
                            <td>{{account.trustLevel.id}}</td>
                            <td>{{account.time_read}}</td>
                            <td>{{account.topics_entered}}</td>
                            <td>{{account.post_count}}</td>
                          </tr>
                        {{/each}}
                      </tbody>
                    </table>
                  </dd>
                {{/if}}
              </ConditionalLoadingSpinner>
            </dl>
            <div class="powered-by">{{htmlSafe
                (i18n "ip_lookup.powered_by")
              }}</div>
          </div>
        </div>
      </:content>
    </DMenu>
  </template>
}
