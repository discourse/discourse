const DesignWizardSection = <template>
  <section class="design-wizard-modal__section" data-section-id={{@id}}>
    <span class="design-wizard-modal__section-title">{{@title}}</span>
    <div class="design-wizard-modal__section-body">
      {{yield}}
    </div>
  </section>
</template>;

export default DesignWizardSection;
