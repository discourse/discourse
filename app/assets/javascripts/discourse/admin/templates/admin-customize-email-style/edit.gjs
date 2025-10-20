import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import EmailStylesEditor from "admin/components/email-styles-editor";

export default RouteTemplate(
  <template>
    <EmailStylesEditor
      @styles={{@controller.model}}
      @fieldName={{@controller.fieldName}}
      @save={{@controller.save}}
    />

    <div class="admin-footer">
      <div class="buttons">
        <DButton
          @action={{@controller.save}}
          @disabled={{@controller.saveDisabled}}
          @translatedLabel={{@controller.saveButtonText}}
          class="btn-primary"
        />
      </div>
    </div>
  </template>
);
