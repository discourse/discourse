import { Textarea } from "@ember/component";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import SaveControls from "discourse/components/save-controls";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="llms-txt-edit">
    <h3>{{i18n "admin.customize.llms.title"}}</h3>
    <p>{{htmlSafe (i18n "admin.customize.llms.description")}}</p>
    <Textarea @value={{@controller.buffered.llms_txt}} class="llms-txt-input" />
    <SaveControls
      @model={{@controller}}
      @action={{@controller.save}}
      @saved={{@controller.saved}}
      @saveDisabled={{@controller.saveDisabled}}
    >
      <DButton
        @disabled={{@controller.resetDisabled}}
        @icon="arrow-rotate-left"
        @action={{@controller.reset}}
        @label="admin.settings.reset"
        class="btn-default"
      />
    </SaveControls>
  </div>
</template>
