import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import GroupLink from "discourse/components/group-link";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { groupPath } from "discourse/lib/url";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import { i18n } from "discourse-i18n";

const PLACES = [
  ["personal_messages", "allow_personal_messages"],
  ["topic_mentions", "allow_topic_mentions"],
  ["chat_direct_messages", "allow_chat_direct_messages"],
  ["chat_channel_mentions", "allow_chat_channel_mentions"],
];

/**
 * Lists the agents that can be chatbots and switches each one on or off.
 * Switching off only removes the places people can reach the agent, so
 * features that use the agent directly keep working.
 *
 * @param {Array} agents - the bot feature's `chatbot_agents`
 * @param {boolean} [disabled]
 * @param {Function} [onChange] - called after a successful save
 */
export default class AiFeaturesChatbotAgents extends Component {
  @tracked _pendingAgentIds = new Set();

  @action
  places(agent) {
    const places = PLACES.filter(([key]) => agent[key]).map(([key]) =>
      i18n(`discourse_ai.features.chatbot.places.${key}`)
    );
    return places.length
      ? places.join(" · ")
      : i18n("discourse_ai.features.chatbot.places.none");
  }

  @action
  toggleLabel(agent) {
    return i18n("discourse_ai.features.chatbot.toggle", { name: agent.name });
  }

  @action
  isSaving(agent) {
    return this._pendingAgentIds.has(agent.id);
  }

  @action
  async toggle(agent) {
    if (this.args.disabled || this.isSaving(agent)) {
      return;
    }

    const hasPlaces = PLACES.some(([key]) => agent[key]);
    const attributes = Object.fromEntries(
      PLACES.map(([key, attribute]) => [
        attribute,
        !agent.chatbot &&
          (hasPlaces ? agent[key] : key === "personal_messages"),
      ])
    );

    this._pendingAgentIds = new Set([...this._pendingAgentIds, agent.id]);
    try {
      await ajax(`/admin/plugins/discourse-ai/ai-agents/${agent.id}.json`, {
        type: "PUT",
        data: { ai_agent: attributes },
      });
      await this.args.onChange?.();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      const pending = new Set(this._pendingAgentIds);
      pending.delete(agent.id);
      this._pendingAgentIds = pending;
    }
  }

  <template>
    <table class="d-table ai-features-chatbot-agents">
      <thead class="d-table__header">
        <tr class="d-table__row">
          <th class="d-table__header-cell">
            {{i18n "discourse_ai.features.table.agent"}}
          </th>
          <th class="d-table__header-cell">
            {{i18n "discourse_ai.features.chatbot.available_in"}}
          </th>
          <th class="d-table__header-cell">
            {{i18n "discourse_ai.features.table.groups"}}
          </th>
          <th class="d-table__header-cell">
            {{i18n "discourse_ai.features.table.llm"}}
          </th>
          <th class="d-table__header-cell">
            {{i18n "discourse_ai.features.chatbot.column"}}
          </th>
        </tr>
      </thead>
      <tbody class="d-table__body">
        {{#each @agents as |agent|}}
          <tr
            class="d-table__row ai-features-chatbot-agents__row
              {{unless agent.chatbot '--off'}}"
            data-agent-id={{agent.id}}
          >
            <td
              class="d-table__cell --overview ai-features-chatbot-agents__name"
            >
              <LinkTo
                @model={{agent.id}}
                @route="adminPlugins.show.discourse-ai-agents.edit"
              >{{agent.name}}</LinkTo>
            </td>
            <td
              class="d-table__cell --detail ai-features-chatbot-agents__places"
            >
              <div class="d-table__mobile-label">
                {{i18n "discourse_ai.features.chatbot.available_in"}}
              </div>
              {{this.places agent}}
            </td>
            <td
              class="d-table__cell --detail ai-features-chatbot-agents__groups"
            >
              <div class="d-table__mobile-label">
                {{i18n "discourse_ai.features.table.groups"}}
              </div>
              <ul class="ai-features-feature-row__group-list">
                {{#each agent.allowed_groups as |group|}}
                  <li>
                    <GroupLink
                      class="mention-group"
                      @href={{groupPath group.name}}
                      @name={{group.name}}
                    >{{group.name}}</GroupLink>
                  </li>
                {{/each}}
              </ul>
            </td>
            <td class="d-table__cell --detail ai-features-chatbot-agents__llm">
              <div class="d-table__mobile-label">
                {{i18n "discourse_ai.features.table.llm"}}
              </div>
              {{#if agent.llm}}
                <LinkTo
                  @model={{agent.llm.id}}
                  @route="adminPlugins.show.discourse-ai-llms.edit"
                >{{agent.llm.name}}</LinkTo>
              {{else}}
                <span class="ai-features-chatbot-agents__any-llm">
                  {{i18n "discourse_ai.features.chatbot.any_llm"}}
                </span>
              {{/if}}
            </td>
            <td
              class="d-table__cell --detail ai-features-chatbot-agents__toggle"
            >
              <div class="d-table__mobile-label">
                {{i18n "discourse_ai.features.chatbot.column"}}
              </div>
              <DToggleSwitch
                aria-label={{this.toggleLabel agent}}
                class="ai-features-chatbot-agents__switch"
                disabled={{if @disabled true (this.isSaving agent)}}
                @state={{agent.chatbot}}
                {{on "click" (fn this.toggle agent)}}
              />
            </td>
          </tr>
        {{/each}}
      </tbody>
    </table>
    <div class="ai-features-chatbot-agents__footer">
      <LinkTo
        class="btn btn-default btn-small"
        @route="adminPlugins.show.discourse-ai-agents.new"
      >{{i18n "discourse_ai.features.chatbot.new_agent"}}</LinkTo>
      <LinkTo
        class="ai-features-chatbot-agents__manage"
        @route="adminPlugins.show.discourse-ai-agents"
      >{{i18n "discourse_ai.features.chatbot.manage_agents"}}</LinkTo>
    </div>
  </template>
}
