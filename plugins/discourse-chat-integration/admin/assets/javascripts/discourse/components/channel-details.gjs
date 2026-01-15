import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import ChannelData from "./channel-data";
import RuleRow from "./rule-row";

export default class ChannelDetails extends Component {
  @service dialog;
  @service siteSettings;

  @action
  deleteChannel(channel) {
    this.dialog.deleteConfirm({
      message: i18n("chat_integration.channel_delete_confirm"),
      didConfirm: () => {
        return channel
          .destroyRecord()
          .then(() => this.args.refresh())
          .catch(popupAjaxError);
      },
    });
  }

  <template>
    <div class="channel-details">
      <div class="channel-header">
        <div class="pull-right">
          <DButton
            @icon="pencil"
            @title="chat_integration.edit_channel"
            @label="chat_integration.edit_channel"
            @action={{fn @editChannel @channel}}
          />

          <DButton
            @icon="rocket"
            @title="chat_integration.test_channel"
            @label="chat_integration.test_channel"
            @action={{fn @test @channel}}
            class="btn-chat-test"
          />

          <DButton
            @icon="trash-can"
            @title="chat_integration.delete_channel"
            @label="chat_integration.delete_channel"
            @action={{fn this.deleteChannel @channel}}
            class="cancel delete-channel"
          />
        </div>

        <span class="channel-title">
          {{#if @channel.error_key}}
            <DButton
              @icon="triangle-exclamation"
              @action={{fn @showError @channel}}
              class="delete btn-danger"
            />
          {{/if}}

          <ChannelData @provider={{@provider}} @channel={{@channel}} />
        </span>
      </div>
      <div class="channel-body">
        <table>
          <thead>
            <tr>
              <th>{{i18n "chat_integration.rule_table.filter"}}</th>
              <th>{{i18n "chat_integration.rule_table.category"}}</th>

              {{#if this.siteSettings.tagging_enabled}}
                <th>{{i18n "chat_integration.rule_table.tags"}}</th>
              {{/if}}

              <th></th>
            </tr>
          </thead>

          <tbody>
            {{#each @channel.rules as |rule|}}
              <RuleRow
                @rule={{rule}}
                @edit={{fn @editRuleWithChannel rule @channel}}
                @refresh={{@refresh}}
              />
            {{/each}}
          </tbody>
        </table>
      </div>

      <div class="channel-footer">
        <div class="pull-right">
          <DButton
            @icon="plus"
            @title="chat_integration.create_rule"
            @label="chat_integration.create_rule"
            @action={{fn @createRule @channel}}
          />
        </div>
      </div>
    </div>
  </template>
}
