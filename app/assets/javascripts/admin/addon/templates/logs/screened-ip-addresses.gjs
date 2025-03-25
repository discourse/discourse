import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import TextField from "discourse/components/text-field";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ScreenedIpAddressForm from "admin/components/screened-ip-address-form";

export default RouteTemplate(
  <template>
    <DPageSubheader
      @descriptionLabel={{i18n
        "admin.config.staff_action_logs.sub_pages.screened_ips.header_description"
      }}
    />

    <div class="screened-ip-controls">
      <div class="filter-screened-ip-address inline-form">
        <TextField
          @value={{@controller.filter}}
          @placeholderKey="admin.logs.screened_ips.form.filter"
          @autocorrect="off"
          @autocapitalize="off"
          class="ip-address-input"
        />
        <DButton
          @action={{@controller.exportScreenedIpList}}
          @icon="download"
          @title="admin.export_csv.button_title.screened_ip"
          @label="admin.export_csv.button_text"
          class="btn-default"
        />
      </div>

      <ScreenedIpAddressForm @action={{@controller.recordAdded}} />
    </div>

    <ConditionalLoadingSpinner @condition={{@controller.loading}}>
      {{#if @controller.model.length}}
        <table class="admin-logs-table screened-ip-addresses grid">
          <thead class="heading-container">
            <th class="col heading first ip_address">{{i18n
                "admin.logs.ip_address"
              }}</th>
            <th class="col heading action">{{i18n "admin.logs.action"}}</th>
            <th class="col heading match_count">{{i18n
                "admin.logs.match_count"
              }}</th>
            <th class="col heading created_at">{{i18n
                "admin.logs.created_at"
              }}</th>
            <th class="col heading last_match_at">{{i18n
                "admin.logs.last_match_at"
              }}</th>
            <th class="col heading actions"></th>
          </thead>
          <tbody>
            {{#each @controller.model as |item|}}
              <tr class="admin-list-item">
                <td class="col first ip_address">
                  {{#if item.editing}}
                    <TextField
                      @value={{item.ip_address}}
                      @autofocus="autofocus"
                    />
                  {{else}}
                    <a
                      href
                      {{on "click" (fn @controller.edit item)}}
                      class="inline-editable-field"
                    >
                      {{#if item.isRange}}
                        <strong>{{item.ip_address}}</strong>
                      {{else}}
                        {{item.ip_address}}
                      {{/if}}
                    </a>
                  {{/if}}
                </td>
                <td class="col action">
                  {{#if item.isBlocked}}
                    {{icon "ban"}}
                  {{else}}
                    {{icon "check"}}
                  {{/if}}
                  {{item.actionName}}
                </td>
                <td class="col match_count">
                  <div class="label">{{i18n "admin.logs.match_count"}}</div>
                  {{item.match_count}}
                </td>
                <td class="col created_at">
                  <div class="label">{{i18n "admin.logs.created_at"}}</div>
                  {{ageWithTooltip item.created_at}}
                </td>
                <td class="col last_match_at">
                  {{#if item.last_match_at}}
                    <div class="label">{{i18n "admin.logs.last_match_at"}}</div>
                    {{ageWithTooltip item.last_match_at}}
                  {{/if}}
                </td>
                <td class="col actions">
                  {{#if item.editing}}
                    <DButton
                      @action={{fn @controller.save item}}
                      @label="admin.logs.save"
                      class="btn-default"
                    />
                    <DButton
                      @action={{fn @controller.cancel item}}
                      @translatedLabel={{i18n "cancel"}}
                      class="btn-flat"
                    />
                  {{else}}
                    <DButton
                      @action={{fn @controller.destroyRecord item}}
                      @icon="trash-can"
                      class="btn-default btn-danger"
                    />
                    <DButton
                      @action={{fn @controller.edit item}}
                      @icon="pencil"
                      class="btn-default"
                    />
                    {{#if item.isBlocked}}
                      <DButton
                        @action={{fn @controller.allow item}}
                        @icon="check"
                        @label="admin.logs.screened_ips.actions.do_nothing"
                        class="btn-default"
                      />
                    {{else}}
                      <DButton
                        @action={{fn @controller.block item}}
                        @icon="ban"
                        @label="admin.logs.screened_ips.actions.block"
                        class="btn-default"
                      />
                    {{/if}}
                  {{/if}}
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        {{i18n "search.no_results"}}
      {{/if}}
    </ConditionalLoadingSpinner>
  </template>
);
