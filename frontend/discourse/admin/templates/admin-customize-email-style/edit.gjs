import EmailStylesEditor from "discourse/admin/components/email-styles-editor";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";

export default <template>
  <PluginOutlet
    @name="admin-customize-email-style-edit"
    @connectorTagName="div"
  >
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
  </PluginOutlet>
</template>
