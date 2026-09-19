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
      class="robots-txt-input"
      @value={{@controller.buffered.robots_txt}}
    />
    <DSaveControls
      @action={{@controller.save}}
      @model={{@controller}}
      @saved={{@controller.saved}}
      @saveDisabled={{@controller.saveDisabled}}
    >
      <DButton
        class="btn-default"
        @action={{@controller.reset}}
        @disabled={{@controller.resetDisabled}}
        @icon="arrow-rotate-left"
        @label="admin.settings.reset"
      />
    </DSaveControls>
  </div>
</template>
