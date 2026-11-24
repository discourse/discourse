import { fn, hash } from "@ember/helper";
import { trustHTML } from "@ember/template";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import ComboBox from "discourse/select-kit/components/combo-box";
import ListSetting from "discourse/select-kit/components/list-setting";
import DButton from "discourse/ui-kit/d-button";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";

const META_URL =
  "https://meta.discourse.org/t/configure-patreon-integration-with-discourse/62380";

function updateFilter(rule, property, value) {
  rule.set(property, value);
}

/** A reward's printed name as the picker's record. */
function rewardRecords(names) {
  return (names ?? []).map((name) => ({ id: name, name }));
}

export default <template>
  <section id="patreon">
    {{#if @controller.unconfigured}}
      <AdminConfigAreaEmptyList
        class="patreon-unconfigured"
        @ctaLabel="patreon.configure_tokens"
        @ctaRoute="adminPlugins.show.settings"
        @ctaRouteModels="discourse-patreon"
        @emptyLabelTranslated={{i18n "patreon.unconfigured" url=META_URL}}
      />
    {{else}}
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
                    class="delete btn-danger"
                    @action={{@controller.delete}}
                    @actionParam={{rule}}
                    @icon="far-trash-can"
                    @title="patreon.delete"
                  />
                </div>
              </td>
            </tr>
          {{/each}}
        </tbody>

        <tfoot>
          <tr class="new-filter">
            <td><ComboBox
                @content={{@controller.groups}}
                @nameProperty="name"
                @none="patreon.select_group"
                @onChange={{fn updateFilter @controller.editing "group_id"}}
                @value={{@controller.editing.group_id}}
                @valueProperty="id"
              /></td>
            <td>
              {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
              {{#if @controller.siteSettings.enable_new_select_controls}}
                <DSelect
                  class="rewards"
                  @multiple={{true}}
                  @onChange={{fn
                    updateFilter
                    @controller.editing
                    "reward_list"
                  }}
                  @options={{rewardRecords @controller.rewardsNames}}
                  @texts={{hash ariaLabel=(i18n "patreon.rewards")}}
                  @value={{@controller.editing.reward_list}}
                />
              {{else}}
                <ListSetting
                  class="rewards"
                  @choices={{@controller.rewardsNames}}
                  @onChange={{fn
                    updateFilter
                    @controller.editing
                    "reward_list"
                  }}
                  @value={{@controller.editing.reward_list}}
                />
              {{/if}}
            </td>
            <td>
              <div class="pull-right">
                <DButton
                  class="save btn-primary"
                  @action={{@controller.save}}
                  @icon="check"
                  @title="patreon.save"
                />
              </div>
            </td>
          </tr>
        </tfoot>
      </table>

      <p>{{i18n "patreon.help_text"}}</p>

      <DButton
        @action={{@controller.updateData}}
        @disabled={{@controller.updatingData}}
        @icon="refresh"
        @label="patreon.update_data"
        @title="patreon.update_data"
      />

      {{#if @controller.last_sync_at}}
        <span class="last_synced">
          {{i18n "patreon.last_synced"}}:
          {{trustHTML (dFormatDate @controller.last_sync_at leaveAgo="true")}}
        </span>
      {{/if}}
    {{/if}}
  </section>
</template>
