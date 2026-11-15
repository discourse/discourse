import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import GroupLink from "discourse/components/group-link";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { groupPath } from "discourse/lib/url";
import Group from "discourse/models/group";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

/**
 * Shows and edits who can use a feature, which is the allowed groups of its
 * agent. Clearing every group turns the feature off for everyone.
 *
 * @param {{ id: number, allowed_groups: Array<{ id: number, name: string }> }} agent
 * @param {string} featureName - localized, for the accessible edit label
 * @param {Array<{ module_name: string, name: string }>} [sharedWith] - other features using the agent
 * @param {Function} [onChange] - called after a successful save
 */
export default class AiFeatureAgentGroups extends Component {
  @service site;

  @tracked allGroups = [];
  @tracked editing = false;
  @tracked groupIds = [];
  @tracked saving = false;
  @tracked loading = false;

  get editLabel() {
    return i18n("discourse_ai.features.who_can_use.edit", {
      name: this.args.featureName,
    });
  }

  get sharedWithNames() {
    return (this.args.sharedWith || [])
      .map(({ module_name, name }) =>
        i18n(`discourse_ai.features.${module_name}.${name}`)
      )
      .join(", ");
  }

  @action
  async edit() {
    this.loading = true;
    try {
      const groups = await Group.findAll({ include_everyone: true });
      if (this.isDestroying) {
        return;
      }
      if (!groups.some((group) => group.id === AUTO_GROUPS.everyone.id)) {
        groups.push(this.site.groupsById[AUTO_GROUPS.everyone.id]);
      }
      this.allGroups = groups;
      this.groupIds = this.args.agent.allowed_groups.map((group) => group.id);
      this.editing = true;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  cancel() {
    this.editing = false;
  }

  @action
  updateGroups(groupIds) {
    this.groupIds = groupIds;
  }

  @action
  async save() {
    this.saving = true;
    try {
      // JSON keeps an empty list, which form encoding would drop.
      await ajax(
        `/admin/plugins/discourse-ai/ai-agents/${this.args.agent.id}.json`,
        {
          type: "PUT",
          contentType: "application/json",
          data: JSON.stringify({
            ai_agent: { allowed_group_ids: this.groupIds },
          }),
        }
      );
      this.editing = false;
      await this.args.onChange?.();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <div class="ai-feature-agent-groups">
      {{#if this.editing}}
        <GroupChooser
          @content={{this.allGroups}}
          @onChange={{this.updateGroups}}
          @value={{this.groupIds}}
        />
        {{#if this.sharedWithNames}}
          <p class="ai-feature-agent-groups__shared">
            {{i18n
              "discourse_ai.features.who_can_use.shared"
              features=this.sharedWithNames
            }}
          </p>
        {{/if}}
        {{#unless this.groupIds.length}}
          <p class="ai-feature-agent-groups__warning">
            {{i18n "discourse_ai.features.who_can_use.no_one_warning"}}
          </p>
        {{/unless}}
        <div class="ai-feature-agent-groups__actions">
          <DButton
            class="btn-primary btn-small ai-feature-agent-groups__save"
            @action={{this.save}}
            @isLoading={{this.saving}}
            @label="save"
          />
          <DButton
            class="btn-flat btn-small ai-feature-agent-groups__cancel"
            @action={{this.cancel}}
            @disabled={{this.saving}}
            @label="cancel"
          />
        </div>
      {{else}}
        <ul class="ai-features-feature-row__group-list">
          {{#each @agent.allowed_groups as |group|}}
            <li>
              <GroupLink
                class="mention-group"
                @href={{groupPath group.name}}
                @name={{group.name}}
              >{{group.name}}</GroupLink>
            </li>
          {{else}}
            <li class="ai-features-feature-row__empty">
              {{i18n "discourse_ai.features.who_can_use.no_one"}}
            </li>
          {{/each}}
          <li>
            <DButton
              class="btn-flat btn-small ai-feature-agent-groups__edit"
              @action={{this.edit}}
              @icon="pencil"
              @isLoading={{this.loading}}
              @translatedAriaLabel={{this.editLabel}}
              @translatedTitle={{this.editLabel}}
            />
          </li>
        </ul>
      {{/if}}
    </div>
  </template>
}
