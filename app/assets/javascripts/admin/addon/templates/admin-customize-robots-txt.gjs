import { Textarea } from "@ember/component";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import SaveControls from "discourse/components/save-controls";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
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
);
