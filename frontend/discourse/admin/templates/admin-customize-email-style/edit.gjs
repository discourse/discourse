import EmailStylesEditor from "discourse/admin/components/email-styles-editor";
import PluginOutlet from "discourse/components/plugin-outlet";
import DButton from "discourse/ui-kit/d-button";

export default <template>
  <PluginOutlet
    @connectorTagName="div"
    @name="admin-customize-email-style-edit"
  >
    <EmailStylesEditor
      @fieldName={{@controller.fieldName}}
      @save={{@controller.save}}
      @styles={{@controller.model}}
    />

    <div class="admin-footer">
      <div class="buttons">
        <DButton
          class="btn-primary"
          @action={{@controller.save}}
          @disabled={{@controller.saveDisabled}}
          @translatedLabel={{@controller.saveButtonText}}
        />
      </div>
    </div>
  </PluginOutlet>
</template>
