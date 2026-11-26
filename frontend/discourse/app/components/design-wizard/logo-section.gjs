import UppyImageUploader from "discourse/components/uppy-image-uploader";

const DesignWizardLogoSection = <template>
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
  </div>
</template>;

export default DesignWizardLogoSection;
