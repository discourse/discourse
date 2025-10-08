import { Textarea } from "@ember/component";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

const IncomingEmail = <template>
  <DModal
    class="admin-incoming-email-modal"
    @title={{i18n "admin.email.incoming_emails.modal.title"}}
    @closeModal={{@closeModal}}
    @bodyClass="incoming-emails"
  >
    <:body>
      {{#if @model.error}}
        <div class="control-group admin-incoming-email-modal__error">
          <label>{{i18n "admin.email.incoming_emails.modal.error"}}</label>

          <div class="controls admin-incoming-email-modal__error-content">
            <p
              class="admin-incoming-email-modal__error-message"
            >{{@model.error}}</p>

            {{#if @model.error_description}}
              <p
                class="error-description admin-incoming-email-modal__error-description"
              >{{@model.error_description}}</p>
            {{/if}}
          </div>
        </div>

        <hr />
      {{/if}}

      <div class="control-group">
        <label>{{i18n "admin.email.incoming_emails.modal.headers"}}</label>
        <div class="controls">
          <Textarea @value={{@model.headers}} wrap="off" />
        </div>
      </div>

      <div class="control-group">
        <label>{{i18n "admin.email.incoming_emails.modal.subject"}}</label>
        <div class="controls">
          {{@model.subject}}
        </div>
      </div>

      <div class="control-group">
        <label>{{i18n "admin.email.incoming_emails.modal.body"}}</label>
        <div class="controls">
          <Textarea @value={{@model.body}} />
        </div>
      </div>

      {{#if @model.rejection_message}}
        <hr />

        <div class="control-group">
          <label>{{i18n
              "admin.email.incoming_emails.modal.rejection_message"
            }}</label>
          <div class="controls">
            <Textarea @value={{@model.rejection_message}} />
          </div>
        </div>
      {{/if}}
    </:body>
  </DModal>
</template>;

export default IncomingEmail;
