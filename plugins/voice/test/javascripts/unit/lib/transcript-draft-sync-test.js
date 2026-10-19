import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import TranscriptDraftSync from "discourse/plugins/voice/discourse/lib/voice/transcript-draft-sync";

module("Voice | Unit | Lib | transcript-draft-sync", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.saves = [];
    this.data = { reply: "transcript", action: "createTopic" };
    this.saveResult = () => ({ draft_sequence: this.saves.length });

    this.sync = new TranscriptDraftSync({
      save: (key, sequence, data) => {
        this.saves.push({ key, sequence, data });
        return Promise.resolve(this.saveResult());
      },
      buildData: () => this.data,
    });
  });

  hooks.afterEach(function () {
    this.sync.dispose();
  });

  test("flushes only when dirty and tracks the sequence", async function (assert) {
    this.sync.start(5, 1000);
    assert.strictEqual(this.sync.key, "new_topic_voice_5_1000");

    await this.sync.flush();
    assert.strictEqual(this.saves.length, 0, "clean flush is a no-op");

    this.sync.markDirty();
    await this.sync.flush();
    assert.strictEqual(this.saves.length, 1);
    assert.strictEqual(this.saves[0].sequence, 0);

    await this.sync.flush();
    assert.strictEqual(this.saves.length, 1, "saved content is not resent");

    this.sync.markDirty();
    await this.sync.flush();
    assert.strictEqual(
      this.saves[1].sequence,
      1,
      "the server's sequence is used for the next save"
    );
  });

  test("does not save an empty transcript", async function (assert) {
    this.sync.start(5, 1000);
    this.data = null;
    this.sync.markDirty();

    await this.sync.flush();

    assert.strictEqual(this.saves.length, 0);
  });

  test("a sequence conflict hands off permanently", async function (assert) {
    let attempts = 0;
    const sync = new TranscriptDraftSync({
      save: () => {
        attempts++;
        return Promise.reject({ jqXHR: { status: 409 } });
      },
      buildData: () => this.data,
    });
    sync.start(7, 3000);

    sync.markDirty();
    await sync.flush();
    assert.strictEqual(attempts, 1);

    sync.markDirty();
    await sync.flush();
    assert.strictEqual(attempts, 1, "a conflicted draft is never retried");
    sync.dispose();
  });

  test("a transient failure retries on the next flush", async function (assert) {
    let attempts = 0;
    const sync = new TranscriptDraftSync({
      save: () => {
        attempts++;
        return attempts === 1
          ? Promise.reject({ jqXHR: { status: 500 } })
          : Promise.resolve({ draft_sequence: 1 });
      },
      buildData: () => this.data,
    });
    sync.start(6, 2000);

    sync.markDirty();
    await sync.flush();
    await sync.flush();

    assert.strictEqual(attempts, 2, "stays dirty and retries");
    sync.dispose();
  });

  test("stop flushes what is pending", async function (assert) {
    this.sync.start(5, 1000);
    this.sync.markDirty();

    await this.sync.stop();

    assert.strictEqual(this.saves.length, 1);
    assert.strictEqual(this.sync.key, "new_topic_voice_5_1000", "key kept");
  });
});
