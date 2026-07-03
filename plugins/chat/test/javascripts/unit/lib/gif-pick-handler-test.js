import { module, test } from "qunit";
import sinon from "sinon";
import { buildGifPickHandler } from "discourse/plugins/chat/discourse/lib/gif-pick-handler";

function setupDraft() {
  const channelDraft = { resetDraft: sinon.spy() };
  const threadDraft = { resetDraft: sinon.spy() };
  return {
    draft: {
      channel: { id: 7, resetDraft: channelDraft.resetDraft },
      thread: { id: 13, resetDraft: threadDraft.resetDraft },
      inReplyTo: { id: 42 },
    },
    channelDraft,
    threadDraft,
  };
}

module("Unit | Lib | buildGifPickHandler", function () {
  test("sends a channel message with inReplyToId when not in a thread", async function (assert) {
    const api = { sendChatMessage: sinon.stub().resolves() };
    const { draft } = setupDraft();
    const currentUser = { id: 1 };

    const handler = buildGifPickHandler({
      api,
      draft,
      isThread: false,
      currentUser,
    });

    await handler("![g](u)");

    assert.true(api.sendChatMessage.calledOnce);
    assert.deepEqual(api.sendChatMessage.firstCall.args, [
      7,
      { message: "![g](u)", threadId: null, inReplyToId: 42 },
    ]);
  });

  test("sends a thread message with threadId when in a thread", async function (assert) {
    const api = { sendChatMessage: sinon.stub().resolves() };
    const { draft } = setupDraft();

    const handler = buildGifPickHandler({
      api,
      draft,
      isThread: true,
      currentUser: { id: 1 },
    });

    await handler("![g](u)");

    assert.deepEqual(api.sendChatMessage.firstCall.args, [
      7,
      { message: "![g](u)", threadId: 13, inReplyToId: null },
    ]);
  });

  test("resets the channel draft on a successful channel-context send", async function (assert) {
    const api = { sendChatMessage: sinon.stub().resolves() };
    const { draft, channelDraft, threadDraft } = setupDraft();
    const currentUser = { id: 1 };

    const handler = buildGifPickHandler({
      api,
      draft,
      isThread: false,
      currentUser,
    });

    await handler("![g](u)");

    assert.true(
      channelDraft.resetDraft.calledOnceWith(currentUser),
      "channel draft is reset"
    );
    assert.false(threadDraft.resetDraft.called, "thread draft is left alone");
  });

  test("resets the thread draft on a successful thread-context send", async function (assert) {
    const api = { sendChatMessage: sinon.stub().resolves() };
    const { draft, channelDraft, threadDraft } = setupDraft();
    const currentUser = { id: 1 };

    const handler = buildGifPickHandler({
      api,
      draft,
      isThread: true,
      currentUser,
    });

    await handler("![g](u)");

    assert.true(
      threadDraft.resetDraft.calledOnceWith(currentUser),
      "thread draft is reset"
    );
    assert.false(
      channelDraft.resetDraft.called,
      "channel draft is left alone in thread context"
    );
  });

  test("does not reset the draft when sendChatMessage rejects", async function (assert) {
    const api = { sendChatMessage: sinon.stub().rejects(new Error("nope")) };
    const { draft, channelDraft } = setupDraft();

    const handler = buildGifPickHandler({
      api,
      draft,
      isThread: false,
      currentUser: { id: 1 },
    });

    await handler("![g](u)");

    assert.false(
      channelDraft.resetDraft.called,
      "draft preserved so the user can retry"
    );
  });
});
