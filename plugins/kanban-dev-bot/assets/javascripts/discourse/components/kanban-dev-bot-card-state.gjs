import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const PHASES = new Set([
  "running",
  "review",
  "stopping",
  "accepted",
  "integrating",
  "deploying",
  "publishing",
  "confirming",
  "done",
  "failed",
  "integration_failed",
  "needs_attention",
  "cancelled",
  "stopped",
]);
const ACTIONS = new Set(["cancel", "restart", "retry"]);

export default class KanbanDevBotCardState extends Component {
  @service messageBus;

  @tracked pending = false;

  refreshGeneration = 0;

  watchCard = modifier(() => {
    if (this.args.mode) {
      return;
    }
    const channel = `/boards/${this.args.card.board_id}`;
    const update = (data) => {
      if (data.card?.id === this.args.card.id) {
        this.refreshGeneration++;
        Object.assign(this.args.card, data.card);
      } else if (data.type === "board_updated") {
        this.refreshCard();
      }
    };
    this.messageBus.subscribe(channel, update);
    return () => this.messageBus.unsubscribe(channel, update);
  });

  get state() {
    return this.args.card.kanban_dev_bot;
  }

  get status() {
    const phase = this.state?.run?.phase || this.state?.run?.status;
    return PHASES.has(phase) ? i18n(`kanban_dev_bot.status.${phase}`) : null;
  }

  get diagnostic() {
    const value = this.state?.run?.diagnostic;
    return typeof value === "string" ? value : null;
  }

  get showStatus() {
    return this.args.mode !== "actions" && this.status;
  }

  get availableActions() {
    if (this.args.mode === "status" || !this.args.board?.canWrite) {
      return [];
    }
    return (this.state?.actions || [])
      .filter((name) => ACTIONS.has(name))
      .map((name) => ({
        name,
        label: `kanban_dev_bot.actions.${name}`,
      }));
  }

  async refreshCard() {
    const generation = ++this.refreshGeneration;
    const state = this.state;
    let result;
    try {
      result = await this.args.onRefreshBoard?.();
    } catch (error) {
      popupAjaxError(error);
      return;
    }
    const card = result?.columns
      ?.flatMap((column) => column.cards || [])
      .find((candidate) => candidate.id === this.args.card.id);
    if (card && generation === this.refreshGeneration && this.state === state) {
      Object.assign(this.args.card, card);
    }
  }

  @action
  async requestAction(name) {
    if (this.pending) {
      return;
    }
    this.pending = true;
    const state = this.state;
    const run = state.run;
    try {
      const result = await ajax("/codex-board-bot/action", {
        type: "POST",
        data: {
          board_id: this.args.card.board_id,
          card_id: this.args.card.id,
          action: name,
          expected_run_id: run?.run_id,
          expected_action_id: run?.action_id,
        },
      });
      if (this.state === state) {
        Object.assign(this.args.card, {
          kanban_dev_bot: result.kanban_dev_bot,
          can_move: result.kanban_dev_bot.can_move,
          can_delete: result.kanban_dev_bot.can_delete,
        });
      }
      await this.refreshCard();
    } catch (error) {
      popupAjaxError(error);
      await this.refreshCard();
    } finally {
      this.pending = false;
    }
  }

  <template>
    {{#if this.state}}
      <div
        class="kanban-dev-bot-card-state"
        data-card-action
        {{this.watchCard}}
      >
        {{#if this.showStatus}}
          <span
            class="kanban-dev-bot-card-state__status"
            role="status"
          >{{this.status}}</span>
          {{#if this.diagnostic}}
            <p
              class="kanban-dev-bot-card-state__diagnostic"
            >{{this.diagnostic}}</p>
          {{/if}}
        {{/if}}
        {{#each this.availableActions as |item|}}
          <DButton
            class="btn-small kanban-dev-bot-card-state__action"
            @action={{fn this.requestAction item.name}}
            @disabled={{this.pending}}
            @label={{item.label}}
          />
        {{/each}}
      </div>
    {{/if}}
  </template>
}
