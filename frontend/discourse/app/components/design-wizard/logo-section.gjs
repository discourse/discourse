import UppyImageUploader from "discourse/components/uppy-image-uploader";
import { i18n } from "discourse-i18n";

const DesignWizardLogoSection = <template>
  <p class="design-wizard__logo-description">
    {{i18n "design_wizard.logo.description"}}
  </p>
  <div class="design-wizard__logo-field">
    <UppyImageUploader
      class="design-wizard__logo-uploader no-repeat contain-image"
      @disabled={{@disabled}}
      @id="design-wizard-logo"
      @imageUrl={{@logoUrl}}
      @onUploadDeleted={{@onRemove}}
      @onUploadDone={{@onUpload}}
      @type="branding"
    />
    <p class="design-wizard__logo-help">
      {{i18n "design_wizard.logo.help_text"}}
    </p>
  </div>
</template>;

export default DesignWizardLogoSection;
