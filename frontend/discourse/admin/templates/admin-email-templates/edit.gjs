import { Input } from "@ember/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import AdminInterpolationKeys from "discourse/admin/components/admin-interpolation-keys";
import DButton from "discourse/components/d-button";
import DEditor from "discourse/components/d-editor";
import PluginOutlet from "discourse/components/plugin-outlet";
import SaveControls from "discourse/components/save-controls";
import icon from "discourse/helpers/d-icon";
import { USER_OPTION_COMPOSITION_MODES } from "discourse/lib/constants";
import { i18n } from "discourse-i18n";

export default <template>
  <PluginOutlet @name="admin-email-templates-edit" @connectorTagName="div">
    <div class="email-template">
      <div class="back-to-email-templates">
        <LinkTo @route="adminEmailTemplates">
          {{icon "angle-left"}}
          {{i18n "admin.customize.email_templates.back"}}
        </LinkTo>
      </div>
      <label>{{i18n "admin.customize.email_templates.subject"}}</label>
      {{#if @controller.hasMultipleSubjects}}
        <h3><LinkTo
            @route="adminSiteText"
            @query={{hash q=@controller.hasMultipleSubjects}}
            class="email-template__has-multiple-subjects"
          >{{i18n
              "admin.customize.email_templates.multiple_subjects"
            }}</LinkTo></h3>
      {{else}}
        <Input
          @value={{@controller.buffered.subject}}
          class="email-template__subject"
          {{on "focusin" @controller.trackTextarea}}
          {{on "focusout" @controller.saveCursorPos}}
        />
      {{/if}}
      <br />

      <label>{{i18n "admin.customize.email_templates.body"}}</label>

      {{#if @controller.hasMultipleBodyTemplates}}
        <h3><LinkTo
            @route="adminSiteText"
            @query={{hash q=@controller.hasMultipleBodyTemplates}}
            class="email-template__has-multiple-bodies"
          >{{i18n
              "admin.customize.email_templates.multiple_bodies"
            }}</LinkTo></h3>
      {{else}}
        <DEditor
          @value={{@controller.buffered.body}}
          @forceEditorMode={{USER_OPTION_COMPOSITION_MODES.markdown}}
          class="email-template__body"
          {{on "focusin" @controller.trackTextarea}}
          {{on "focusout" @controller.saveCursorPos}}
        />
      {{/if}}

      <AdminInterpolationKeys
        @keys={{@controller.interpolationKeysWithStatus}}
        @onInsertKey={{@controller.insertInterpolationKey}}
      />

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
  </PluginOutlet>
</template>
