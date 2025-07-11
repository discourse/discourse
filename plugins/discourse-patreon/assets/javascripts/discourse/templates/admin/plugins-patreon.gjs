import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import formatDate from "discourse/helpers/format-date";
import htmlSafe from "discourse/helpers/html-safe";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import ListSetting from "select-kit/components/list-setting";

export default RouteTemplate(
  <template>
    <section id="patreon">
      <h1>{{i18n "patreon.header.rules"}}</h1>
      <table>
        <thead>
          <tr>
            <th>{{i18n "patreon.group"}}</th>
            <th>{{i18n "patreon.rewards"}}</th>
            <th></th>
          </tr>
        </thead>

        <tbody>
          {{#each @controller.model as |rule|}}
            <tr class>
              <td>{{rule.group}}</td>
              <td>{{rule.rewards}}</td>
              <td>
                <div class="pull-right">
                  <DButton
                    @action={{@controller.delete}}
                    @actionParam={{rule}}
                    @icon="far-trash-can"
                    @title="patreon.delete"
                    class="delete btn-danger"
                  />
                </div>
              </td>
            </tr>
          {{/each}}
        </tbody>

        <tfoot>
          <tr class="new-filter">
            <td><ComboBox
                @value={{@controller.editing.group_id}}
                @content={{@controller.groups}}
                @nameProperty="name"
                @valueProperty="id"
                @none="patreon.select_group"
              /></td>
            <td><ListSetting
                @value={{@controller.editing.reward_list}}
                @choices={{@controller.rewardsNames}}
                class="rewards"
              /></td>
            <td>
              <div class="pull-right">
                <DButton
                  @action={{@controller.save}}
                  @icon="check"
                  @title="patreon.save"
                  class="save btn-primary"
                />
              </div>
            </td>
          </tr>
        </tfoot>
      </table>

      <p>{{i18n "patreon.help_text"}}</p>

      <DButton
        @action={{@controller.updateData}}
        @icon="refresh"
        @disabled={{@controller.updatingData}}
        @title="patreon.update_data"
        @label="patreon.update_data"
      />

      {{#if @controller.last_sync_at}}
        <span class="last_synced">
          {{i18n "patreon.last_synced"}}:
          {{htmlSafe (formatDate @controller.last_sync_at leaveAgo="true")}}
        </span>
      {{/if}}
    </section>
  </template>
);
