<ComboBox
  @value={{this.emailTemplate.id}}
  @content={{this.adminEmailTemplates.sortedTemplates}}
  @onChange={{this.adminEmailTemplates.onSelectTemplate}}
  @nameProperty="title"
/>

<div class="email-template">
  <label>{{i18n "admin.customize.email_templates.subject"}}</label>
  {{#if this.hasMultipleSubjects}}
    <h3><LinkTo
        @route="adminSiteText"
        @query={{hash q=this.hasMultipleSubjects}}
      >{{i18n
          "admin.customize.email_templates.multiple_subjects"
        }}</LinkTo></h3>
  {{else}}
    <Input @value={{this.buffered.subject}} />
  {{/if}}
  <br />

  <label>{{i18n "admin.customize.email_templates.body"}}</label>
  <DEditor @value={{this.buffered.body}} />

  <SaveControls
    @model={{this.emailTemplate}}
    @action={{action "saveChanges"}}
    @saved={{this.saved}}
    @saveDisabled={{this.saveDisabled}}
  >
    {{#if this.emailTemplate.can_revert}}
      <DButton
        @action={{action "revertChanges"}}
        @label="admin.customize.email_templates.revert"
      />
    {{/if}}
  </SaveControls>
</div>