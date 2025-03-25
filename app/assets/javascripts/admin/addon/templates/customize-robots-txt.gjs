import RouteTemplate from 'ember-route-template'
import i18n from "discourse/helpers/i18n";
import { Textarea } from "@ember/component";
import SaveControls from "discourse/components/save-controls";
import DButton from "discourse/components/d-button";
export default RouteTemplate(<template><div class="robots-txt-edit">
  <h3>{{i18n "admin.customize.robots.title"}}</h3>
  <p>{{i18n "admin.customize.robots.warning"}}</p>
  {{#if @controller.model.overridden}}
    <div class="overridden">
      {{i18n "admin.customize.robots.overridden"}}
    </div>
  {{/if}}
  <Textarea @value={{@controller.buffered.robots_txt}} class="robots-txt-input" />
  <SaveControls @model={{@controller}} @action={{action "save"}} @saved={{@controller.saved}} @saveDisabled={{@controller.saveDisabled}}>
    <DButton @disabled={{@controller.resetDisabled}} @icon="arrow-rotate-left" @action={{@controller.reset}} @label="admin.settings.reset" class="btn-default" />
  </SaveControls>
</div></template>)