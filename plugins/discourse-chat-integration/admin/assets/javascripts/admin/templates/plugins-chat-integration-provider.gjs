import { fn } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ChannelDetails from "../components/channel-details";

export default RouteTemplate(
  <template>
    {{#if @controller.anyErrors}}
      <div class="error">
        {{icon "triangle-exclamation"}}
        <span class="error-message">
          {{i18n "chat_integration.channels_with_errors"}}
        </span>
      </div>
    {{/if}}

    {{#each @controller.model.channels.content as |channel|}}
      <ChannelDetails
        @channel={{channel}}
        @provider={{@controller.model.provider}}
        @refresh={{@controller.refresh}}
        @editChannel={{@controller.editChannel}}
        @test={{@controller.testChannel}}
        @createRule={{@controller.createRule}}
        @editRuleWithChannel={{@controller.editRuleWithChannel}}
        @showError={{@controller.showError}}
      />
    {{/each}}

    <div class="table-footer">
      <div class="pull-right">
        <DButton
          @action={{fn @controller.createChannel @controller.model.provider}}
          @label="chat_integration.create_channel"
          @icon="plus"
          id="create-channel"
        />
      </div>
    </div>
  </template>
);
