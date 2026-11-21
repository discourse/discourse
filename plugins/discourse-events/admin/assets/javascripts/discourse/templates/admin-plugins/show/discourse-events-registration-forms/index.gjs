import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import DButton from "discourse/ui-kit/d-button";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import DeleteRegistrationFormButton from "discourse/plugins/discourse-events/discourse/components/delete-registration-form-button";
import RegistrationFormCreatorCell from "discourse/plugins/discourse-events/discourse/components/registration-form-creator-cell";

function showTooltipOnFocus(tooltip) {
  tooltip.trigger.addEventListener("focus", tooltip.show);
  tooltip.trigger.addEventListener("blur", tooltip.close);
}

export default <template>
  <div class="admin-config-page__main-area">
    <DPageSubheader
      @descriptionLabel={{i18n "event_registration.library.description"}}
      @titleLabel={{i18n "event_registration.library.title"}}
    >
      <:actions as |actions|>
        <actions.Primary
          @icon="plus"
          @label="event_registration.library.new_form"
          @route="adminPlugins.show.discourse-events-registration-forms.new"
        />
      </:actions>
    </DPageSubheader>
    <table
      aria-label={{i18n "event_registration.library.title"}}
      class="d-table"
    >
      <thead class="d-table__header">
        <tr class="d-table__row">
          <th class="d-table__header-cell" scope="col">{{i18n
              "form_definition.title"
            }}</th>
          <th class="d-table__header-cell" scope="col">{{i18n
              "event_registration.library.events"
            }}</th>
          <th class="d-table__header-cell" scope="col">{{i18n
              "event_registration.library.created_by"
            }}</th>
          <th class="d-table__header-cell" scope="col">
            <span class="sr-only">{{i18n
                "event_registration.library.actions"
              }}</span>
          </th>
        </tr>
      </thead>
      <tbody class="d-table__body">
        {{#each @model key="id" as |form|}}
          <tr class="d-table__row">
            <td class="d-table__cell --overview">
              {{#if form.builtin}}
                <div class="d-table__overview-name">{{form.title}}</div>
              {{else}}
                <LinkTo
                  class="d-table__overview-link"
                  @model={{form.id}}
                  @route="adminPlugins.show.discourse-events-registration-forms.edit"
                >
                  <div class="d-table__overview-name">{{form.title}}</div>
                </LinkTo>
              {{/if}}
              {{#if form.description}}
                <div class="d-table__overview-about">{{form.description}}</div>
              {{/if}}
            </td>
            <td class="d-table__cell --detail">
              <span class="d-table__mobile-label">{{i18n
                  "event_registration.library.events"
                }}</span>
              {{#if form.event_count}}
                <LinkTo
                  aria-label={{i18n
                    "event_registration.library.events_for_form"
                    title=form.title
                    count=form.event_count
                  }}
                  @query={{hash formId=form.id page=1}}
                  @route="adminPlugins.show.discourse-events-submissions"
                >{{form.event_count}}</LinkTo>
              {{else}}
                0
              {{/if}}
            </td>
            <RegistrationFormCreatorCell @form={{form}} />
            <td class="d-table__cell --controls">
              <div class="d-table__cell-actions">
                {{#if form.builtin}}
                  <DTooltip
                    aria-label={{i18n
                      "event_registration.library.built_in_default"
                    }}
                    role="group"
                    tabindex="0"
                    @content={{i18n
                      "event_registration.library.built_in_default"
                    }}
                    @onRegisterApi={{showTooltipOnFocus}}
                  >
                    <:trigger>
                      <DButton
                        class="btn-default btn-small"
                        @disabled={{true}}
                        @label="edit"
                      />
                    </:trigger>
                  </DTooltip>
                {{else}}
                  <DButton
                    class="btn-default btn-small"
                    @label="edit"
                    @route="adminPlugins.show.discourse-events-registration-forms.edit"
                    @routeModels={{form.id}}
                    @translatedAriaLabel={{i18n
                      "event_registration.library.edit_named_form"
                      title=form.title
                    }}
                  />
                  <DeleteRegistrationFormButton
                    class="btn-default btn-small"
                    @formId={{form.id}}
                    @formTitle={{form.title}}
                    @inUse={{form.in_use}}
                  />
                {{/if}}
              </div>
            </td>
          </tr>
        {{/each}}
      </tbody>
    </table>
  </div>
</template>
