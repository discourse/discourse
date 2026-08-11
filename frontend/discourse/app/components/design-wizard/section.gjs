const DesignWizardSection = <template>
  <section class="design-wizard__section" ...attributes>
    <h3 class="design-wizard__section-title">{{@title}}</h3>
    <div class="design-wizard__section-body">
      {{yield}}
    </div>
  </section>
</template>;

export default DesignWizardSection;
