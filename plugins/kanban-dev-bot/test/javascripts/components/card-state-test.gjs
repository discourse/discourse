import { getOwner } from "@ember/owner";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import Card from "discourse/plugins/boards/discourse/models/card";
import KanbanDevBotCardState from "discourse/plugins/kanban-dev-bot/discourse/components/kanban-dev-bot-card-state";

module("Integration | Component | KanbanDevBotCardState", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.board = { canWrite: true };
    this.card = new Card({
      id: 50,
      board_id: 1,
      can_move: false,
      can_delete: true,
      kanban_dev_bot: {
        can_move: false,
        can_delete: true,
        run: { run_id: "run-50", action_id: "action-1", status: "running" },
        actions: ["cancel", "restart"],
      },
    });
  });

  test("shows explicit actions for an active run", async function (assert) {
    await render(
      <template>
        <KanbanDevBotCardState @board={{this.board}} @card={{this.card}} />
      </template>
    );
    assert.dom("[role=status]").includesText("Bot is working");
    assert.dom(".kanban-dev-bot-card-state__action").exists({ count: 2 });
  });

  test("does not offer actions to a board reader", async function (assert) {
    this.board = { canWrite: false };
    await render(
      <template>
        <KanbanDevBotCardState @board={{this.board}} @card={{this.card}} />
      </template>
    );
    assert.dom("[role=status]").exists();
    assert.dom(".kanban-dev-bot-card-state__action").doesNotExist();
  });

  test("sends the run and action generation and displays stopping", async function (assert) {
    pretender.post("/codex-board-bot/action", (request) => {
      const data = new URLSearchParams(request.requestBody);
      assert.strictEqual(data.get("expected_run_id"), "run-50");
      assert.strictEqual(data.get("expected_action_id"), "action-1");
      assert.strictEqual(data.get("action"), "cancel");
      return response({
        kanban_dev_bot: {
          can_move: false,
          can_delete: false,
          run: {
            run_id: "run-50",
            action_id: "action-2",
            status: "stopping",
          },
          actions: [],
        },
      });
    });
    await render(
      <template>
        <KanbanDevBotCardState @board={{this.board}} @card={{this.card}} />
      </template>
    );
    await click(".kanban-dev-bot-card-state__action");
    assert.dom("[role=status]").includesText("Stopping work");
    assert.dom(".kanban-dev-bot-card-state__action").doesNotExist();
  });

  test("refreshes a stale modal generation before the next action", async function (assert) {
    sinon.stub(getOwner(this).lookup("service:dialog"), "alert");
    const freshState = {
      run: { run_id: "run-51", action_id: "action-3", status: "running" },
      actions: ["cancel", "restart"],
      can_move: false,
      can_delete: true,
    };
    let requests = 0;
    this.refresh = async () => ({
      columns: [
        {
          cards: [
            {
              id: 50,
              kanban_dev_bot: freshState,
              can_move: false,
              can_delete: true,
            },
          ],
        },
      ],
    });
    pretender.post("/codex-board-bot/action", (request) => {
      const data = new URLSearchParams(request.requestBody);
      requests++;
      assert.strictEqual(
        data.get("expected_run_id"),
        requests === 1 ? "run-50" : "run-51"
      );
      assert.strictEqual(
        data.get("expected_action_id"),
        requests === 1 ? "action-1" : "action-3"
      );
      return requests === 1
        ? response(409, { errors: ["The run has changed"] })
        : response({ kanban_dev_bot: freshState });
    });
    await render(
      <template>
        <KanbanDevBotCardState
          @board={{this.board}}
          @card={{this.card}}
          @onRefreshBoard={{this.refresh}}
        />
      </template>
    );
    await click(".kanban-dev-bot-card-state__action");
    assert.strictEqual(this.card.kanban_dev_bot, freshState);
    await click(".kanban-dev-bot-card-state__action");
    assert.strictEqual(requests, 2);
    sinon.restore();
  });

  test("a late action response cannot replace a newer MessageBus generation", async function (assert) {
    const messageBus = getOwner(this).lookup("service:message-bus");
    const subscribe = sinon.stub(messageBus, "subscribe");
    sinon.stub(messageBus, "unsubscribe");
    const newerState = {
      run: { run_id: "run-51", action_id: "action-3", status: "review" },
      actions: ["restart"],
      can_move: true,
      can_delete: true,
    };
    pretender.post("/codex-board-bot/action", () => {
      subscribe.lastCall.args[1]({
        card: {
          id: 50,
          kanban_dev_bot: newerState,
          can_move: true,
          can_delete: true,
        },
      });
      return response({
        kanban_dev_bot: {
          run: { run_id: "run-50", action_id: "action-2", status: "stopping" },
          actions: [],
          can_move: false,
          can_delete: false,
        },
      });
    });
    await render(
      <template>
        <KanbanDevBotCardState @board={{this.board}} @card={{this.card}} />
      </template>
    );
    await click(".kanban-dev-bot-card-state__action");
    assert.strictEqual(this.card.kanban_dev_bot, newerState);
    assert.true(this.card.can_move);
    assert.dom("[role=status]").includesText("Ready for review");
    sinon.restore();
  });

  test("topic card board events refresh the retained modal card", async function (assert) {
    const messageBus = getOwner(this).lookup("service:message-bus");
    const subscribe = sinon.stub(messageBus, "subscribe");
    sinon.stub(messageBus, "unsubscribe");
    let phase = "stopping";
    this.refresh = async () => ({
      columns: [
        {
          cards: [
            {
              id: 50,
              kanban_dev_bot: {
                run: { run_id: "run-50", action_id: phase, status: phase },
                actions: [],
                can_move: false,
                can_delete: false,
              },
              can_move: false,
              can_delete: false,
            },
          ],
        },
      ],
    });
    await render(
      <template>
        <KanbanDevBotCardState
          @board={{this.board}}
          @card={{this.card}}
          @onRefreshBoard={{this.refresh}}
        />
      </template>
    );
    const retainedCard = this.card;
    subscribe.lastCall.args[1]({ type: "board_updated" });
    await settled();
    assert.strictEqual(this.card, retainedCard);
    assert.dom("[role=status]").includesText("Stopping work");
    assert.dom(".kanban-dev-bot-card-state__action").doesNotExist();
    phase = "accepted";
    subscribe.lastCall.args[1]({ type: "board_updated" });
    await settled();
    assert.strictEqual(this.card.kanban_dev_bot.run.status, "accepted");
    assert.false(this.card.can_delete);
    assert.dom(".kanban-dev-bot-card-state__action").doesNotExist();
    sinon.restore();
  });

  for (const completionOrder of [
    [0, 1],
    [1, 0],
  ]) {
    test(`overlapping refreshes keep the latest phase when resolved ${completionOrder}`, async function (assert) {
      const messageBus = getOwner(this).lookup("service:message-bus");
      const subscribe = sinon.stub(messageBus, "subscribe");
      sinon.stub(messageBus, "unsubscribe");
      const resolveRefresh = [];
      this.refresh = () =>
        new Promise((resolve) => resolveRefresh.push(resolve));
      await render(
        <template>
          <KanbanDevBotCardState
            @board={{this.board}}
            @card={{this.card}}
            @onRefreshBoard={{this.refresh}}
          />
        </template>
      );
      const update = subscribe.lastCall.args[1];
      update({ type: "board_updated" });
      update({ type: "board_updated" });
      for (const index of completionOrder) {
        const phase = index === 0 ? "stopping" : "accepted";
        resolveRefresh[index]({
          columns: [
            {
              cards: [
                {
                  id: 50,
                  kanban_dev_bot: {
                    run: { run_id: "run-50", action_id: phase, status: phase },
                    actions: [],
                    can_move: false,
                    can_delete: false,
                  },
                  can_move: false,
                  can_delete: false,
                },
              ],
            },
          ],
        });
        await settled();
      }
      assert.strictEqual(this.card.kanban_dev_bot.run.status, "accepted");
      assert.false(this.card.can_delete);
      assert.dom(".kanban-dev-bot-card-state__action").doesNotExist();
      sinon.restore();
    });
  }

  test("a direct card event invalidates a pending board refresh", async function (assert) {
    const messageBus = getOwner(this).lookup("service:message-bus");
    const subscribe = sinon.stub(messageBus, "subscribe");
    sinon.stub(messageBus, "unsubscribe");
    let resolveRefresh;
    this.refresh = () =>
      new Promise((resolve) => {
        resolveRefresh = resolve;
      });
    await render(
      <template>
        <KanbanDevBotCardState
          @board={{this.board}}
          @card={{this.card}}
          @onRefreshBoard={{this.refresh}}
        />
      </template>
    );
    const update = subscribe.lastCall.args[1];
    update({ type: "board_updated" });
    update({ card: { id: 50, can_delete: false } });
    resolveRefresh({
      columns: [{ cards: [{ id: 50, can_delete: true }] }],
    });
    await settled();
    assert.false(this.card.can_delete);
    sinon.restore();
  });

  test("failed event refresh is reported without an unhandled rejection", async function (assert) {
    const messageBus = getOwner(this).lookup("service:message-bus");
    const subscribe = sinon.stub(messageBus, "subscribe");
    sinon.stub(messageBus, "unsubscribe");
    const alert = sinon.stub(getOwner(this).lookup("service:dialog"), "alert");
    this.refresh = async () => {
      throw new Error("Refresh failed");
    };
    await render(
      <template>
        <KanbanDevBotCardState
          @board={{this.board}}
          @card={{this.card}}
          @onRefreshBoard={{this.refresh}}
        />
      </template>
    );
    subscribe.lastCall.args[1]({ type: "board_updated" });
    await settled();
    assert.true(alert.calledOnce);
    assert.dom("[role=status]").includesText("Bot is working");
    sinon.restore();
  });

  test("accepted work exposes only the server-provided retry action", async function (assert) {
    this.card.kanban_dev_bot = {
      run: { status: "needs_attention" },
      actions: ["retry"],
    };
    await render(
      <template>
        <KanbanDevBotCardState @board={{this.board}} @card={{this.card}} />
      </template>
    );
    assert.dom("[role=status]").includesText("remains locked");
    assert.dom(".kanban-dev-bot-card-state__action").exists({ count: 1 });
    assert
      .dom(".kanban-dev-bot-card-state__action")
      .hasText("Retry publishing workflow");
  });

  test("optimistic card copies preserve lifecycle restrictions", function (assert) {
    const copy = this.card.copy({ column_id: 2 });
    assert.false(copy.can_move);
    assert.true(copy.can_delete);
    assert.strictEqual(copy.kanban_dev_bot, this.card.kanban_dev_bot);
  });
});
