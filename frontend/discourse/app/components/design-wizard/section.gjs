const DesignWizardSection = <template>
  <section class="design-wizard__section --section-{{@type}}" ...attributes>
    {{#if @title}}
      <h3 class="design-wizard__section-title">{{@title}}</h3>
    {{/if}}
    <div class="design-wizard__section-body">
      {{yield}}
    </div>
  </section>
</template>;

export default DesignWizardSection;
