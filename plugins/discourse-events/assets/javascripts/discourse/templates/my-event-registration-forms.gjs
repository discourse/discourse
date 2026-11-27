import { LinkTo } from "@ember/routing";
import DButton from "discourse/ui-kit/d-button";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import DeleteRegistrationFormButton from "../components/delete-registration-form-button.gjs";
import RegistrationFormCreatorCell from "../components/registration-form-creator-cell.gjs";

export default <template>
  <section class="event-registration-form-page">
    <DPageSubheader @titleLabel={{i18n "event_registration.library.manage"}}>
      <:actions as |actions|>
        <actions.Primary
          @icon="plus"
          @label="event_registration.library.new_form"
          @route="new-event-registration-form"
        />
      </:actions>
    </DPageSubheader>
    {{#if @model.length}}
      <table
        aria-label={{i18n "event_registration.library.manage"}}
        class="d-table"
      >
        <thead class="d-table__header">
          <tr class="d-table__row">
            <th class="d-table__header-cell" scope="col">{{i18n
                "form_definition.title"
              }}</th>
            <th class="d-table__header-cell" scope="col">{{i18n
                "event_registration.library.created_by"
              }}</th>
            <th class="d-table__header-cell" scope="col"><span
                class="sr-only"
              >{{i18n "event_registration.library.actions"}}</span></th>
          </tr>
        </thead>
        <tbody class="d-table__body">
          {{#each @model key="id" as |form|}}
            <tr class="d-table__row">
              <td class="d-table__cell --overview">
                <LinkTo
                  class="d-table__overview-link"
                  @model={{form.id}}
                  @route="edit-event-registration-form"
                >{{form.title}}</LinkTo>
                {{#if form.description}}<div
                    class="d-table__overview-about"
                  >{{form.description}}</div>{{/if}}
              </td>
              <RegistrationFormCreatorCell @form={{form}} />
              <td class="d-table__cell --controls"><div
                  class="d-table__cell-actions"
                >
                  <DButton
                    class="btn-default btn-small"
                    @icon="pencil"
                    @label="edit"
                    @route="edit-event-registration-form"
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
                </div></td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    {{else}}
      <p>{{i18n "event_registration.library.mine_empty"}}</p>
    {{/if}}
  </section>
</template>
