const DesignWizardSection = <template>
  <section class="design-wizard-modal__section" data-section-id={{@id}}>
    <h3 class="design-wizard-modal__section-title">{{@title}}</h3>
    <div class="design-wizard-modal__section-body">
      {{yield}}
    </div>
  </section>
</template>;

export default DesignWizardSection;
