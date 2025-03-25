import { Input } from "@ember/component";
import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import DEditor from "discourse/components/d-editor";
import SaveControls from "discourse/components/save-controls";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default RouteTemplate(
  <template>
    <ComboBox
      @value={{@controller.emailTemplate.id}}
      @content={{@controller.adminEmailTemplates.sortedTemplates}}
      @onChange={{@controller.adminEmailTemplates.onSelectTemplate}}
      @nameProperty="title"
    />

    <div class="email-template">
      <label>{{i18n "admin.customize.email_templates.subject"}}</label>
      {{#if @controller.hasMultipleSubjects}}
        <h3><LinkTo
            @route="adminSiteText"
            @query={{hash q=@controller.hasMultipleSubjects}}
          >{{i18n
              "admin.customize.email_templates.multiple_subjects"
            }}</LinkTo></h3>
      {{else}}
        <Input @value={{@controller.buffered.subject}} />
      {{/if}}
      <br />

      <label>{{i18n "admin.customize.email_templates.body"}}</label>
      <DEditor @value={{@controller.buffered.body}} />

      <SaveControls
        @model={{@controller.emailTemplate}}
        @action={{@controller.saveChanges}}
        @saved={{@controller.saved}}
        @saveDisabled={{@controller.saveDisabled}}
      >
        {{#if @controller.emailTemplate.can_revert}}
          <DButton
            @action={{@controller.revertChanges}}
            @label="admin.customize.email_templates.revert"
          />
        {{/if}}
      </SaveControls>
    </div>
  </template>
);
