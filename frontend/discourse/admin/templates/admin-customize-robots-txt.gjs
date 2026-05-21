import { Textarea } from "@ember/component";
import DButton from "discourse/ui-kit/d-button";
import DSaveControls from "discourse/ui-kit/d-save-controls";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="robots-txt-edit">
    <h3>{{i18n "admin.customize.robots.title"}}</h3>
    <p>{{i18n "admin.customize.robots.warning"}}</p>
    {{#if @controller.model.overridden}}
      <div class="overridden">
        {{i18n "admin.customize.robots.overridden"}}
      </div>
    {{/if}}
    <Textarea
      @value={{@controller.buffered.robots_txt}}
      class="robots-txt-input"
    />
    <DSaveControls
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
    </DSaveControls>
  </div>
</template>
