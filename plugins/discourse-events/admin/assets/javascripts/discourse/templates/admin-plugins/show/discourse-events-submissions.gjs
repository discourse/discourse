import { concat, fn, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DMenu from "discourse/float-kit/components/d-menu";
import routeAction from "discourse/helpers/route-action";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DFilterControls from "discourse/ui-kit/d-filter-controls";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import DUserLink from "discourse/ui-kit/d-user-link";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import { i18n } from "discourse-i18n";
import DeleteRegistrationFormButton from "discourse/plugins/discourse-events/discourse/components/delete-registration-form-button";

export default <template>
  <div class="admin-config-page__main-area">
    <DPageSubheader
      @descriptionLabel={{i18n "event_registration.submissions.description"}}
      @titleLabel={{i18n "event_registration.submissions.title"}}
    />
    <div class="event-registration-submissions__filters">
      <DFilterInput
        aria-label={{i18n "event_registration.submissions.search"}}
        placeholder={{i18n "event_registration.submissions.search"}}
        @filterAction={{@controller.searchChanged}}
        @icons={{hash left="magnifying-glass"}}
        @onClearInput={{@controller.clearSearch}}
        @value={{@controller.searchInput}}
      />
      <DFilterControls
        @dropdownOptions={{@controller.formOptions}}
        @dropdownValue={{@controller.selectedForm}}
        @onDropdownFilterChange={{@controller.filterByForm}}
        @showNoResults={{false}}
        @showResetButton={{false}}
        @showTextFilter={{false}}
      />
    </div>
    {{#if @model.events.length}}
      <table class="d-table event-registration-submissions">
        <thead class="d-table__header">
          <tr class="d-table__row">
            <th class="d-table__header-cell" scope="col">{{i18n
                "event_registration.submissions.event"
              }}</th>
            <th class="d-table__header-cell" scope="col">{{i18n
                "event_registration.submissions.host"
              }}</th>
            <th class="d-table__header-cell" scope="col">{{i18n
                "event_registration.submissions.form"
              }}</th>
            <th class="d-table__header-cell" scope="col">{{i18n
                "event_registration.submissions.count"
              }}</th>
            <th class="d-table__header-cell" scope="col">{{i18n
                "event_registration.submissions.latest"
              }}</th>
            <th class="d-table__header-cell" scope="col"><span
                class="sr-only"
              >{{i18n "event_registration.submissions.actions"}}</span></th>
          </tr>
        </thead>
        <tbody class="d-table__body">
          {{#each @model.events key="id" as |event|}}
            <tr class="d-table__row">
              <td class="d-table__cell --overview"><a
                  class="d-table__overview-link"
                  href={{getURL event.url}}
                >{{event.title}}</a></td>
              <td class="d-table__cell --detail">
                <span class="d-table__mobile-label">{{i18n
                    "event_registration.submissions.host"
                  }}</span>
                <span class="event-registration-submissions__hosts">
                  {{#each event.hosts key="username" as |host|}}
                    <DUserLink @user={{host}}>
                      {{dAvatar host imageSize="tiny" hideTitle=true}}
                      {{host.username}}
                    </DUserLink>
                  {{else}}
                    —
                  {{/each}}
                </span>
              </td>
              <td class="d-table__cell --detail"><span
                  class="d-table__mobile-label"
                >{{i18n "event_registration.submissions.form"}}</span>{{if
                  event.form_title
                  event.form_title
                  "—"
                }}</td>
              <td class="d-table__cell --detail"><span
                  class="d-table__mobile-label"
                >{{i18n
                    "event_registration.submissions.count"
                  }}</span>{{event.submission_count}}</td>
              <td class="d-table__cell --detail"><span
                  class="d-table__mobile-label"
                >{{i18n "event_registration.submissions.latest"}}</span>{{#if
                  event.latest_submission_at
                }}{{dFormatDate
                    event.latest_submission_at
                  }}{{else}}—{{/if}}</td>
              <td class="d-table__cell --controls"><div
                  class="d-table__cell-actions"
                >
                  {{#if (or event.report_topic_id event.can_export)}}
                    {{#let
                      (i18n
                        "event_registration.submissions.actions_for"
                        event=event.title
                      )
                      as |menuLabel|
                    }}
                      <DMenu
                        @ariaLabel={{menuLabel}}
                        @icon="ellipsis"
                        @placement="bottom-end"
                        @title={{menuLabel}}
                        @triggerClass="btn-small btn-default"
                      >
                        <:content as |menu|>
                          <DDropdownMenu as |dropdown|>
                            {{#if event.report_topic_id}}
                              <dropdown.item>
                                <DButton
                                  class="btn-transparent"
                                  @href={{getURL
                                    (concat "/t/-/" event.report_topic_id)
                                  }}
                                  @icon="envelope"
                                  @label="event_registration.submissions.report"
                                />
                              </dropdown.item>
                            {{/if}}
                            {{#if event.can_export}}
                              <dropdown.item>
                                <DButton
                                  class="btn-transparent"
                                  @action={{fn
                                    @controller.download
                                    event.id
                                    menu.close
                                  }}
                                  @icon="file-csv"
                                  @label="event_registration.submissions.download"
                                />
                              </dropdown.item>
                            {{/if}}
                          </DDropdownMenu>
                        </:content>
                      </DMenu>
                    {{/let}}
                  {{/if}}
                </div></td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    {{else}}
      <AdminConfigAreaEmptyList
        @emptyLabel={{if
          @controller.search
          "event_registration.submissions.no_search_results"
          (if
            @controller.formId
            "event_registration.submissions.empty_for_form"
            "event_registration.submissions.empty"
          )
        }}
      >
        {{#if @model.unused_form}}
          <DeleteRegistrationFormButton
            class="btn-link admin-config-area-empty-list__cta-button"
            @formId={{@model.unused_form.id}}
            @formTitle={{@model.unused_form.title}}
            @label="event_registration.library.delete_form"
            @onDeleted={{routeAction "registrationFormDeleted"}}
          />
        {{/if}}
      </AdminConfigAreaEmptyList>
    {{/if}}
    {{#if @model.previous_page}}<LinkTo
        @query={{hash
          page=@model.previous_page
          formId=@controller.formId
          search=@controller.search
        }}
        @route="adminPlugins.show.discourse-events-submissions"
      >{{i18n "event_registration.submissions.previous"}}</LinkTo>{{/if}}
    {{#if @model.next_page}}<LinkTo
        @query={{hash
          page=@model.next_page
          formId=@controller.formId
          search=@controller.search
        }}
        @route="adminPlugins.show.discourse-events-submissions"
      >{{i18n "event_registration.submissions.next"}}</LinkTo>{{/if}}
  </div>
</template>
