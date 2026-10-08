import { getOwner } from "@ember/owner";
import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import PostEventRecording from "../../discourse/components/modal/post-event-recording";

const RAW = `[event start="2026-10-08 15:00" status="public" livestream="true" location="https://www.youtube.com/live/abc"]
Description
[/event]

Come along!`;

module(
  "Integration | Component | Modal | PostEventRecording",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.post = { raw: RAW, save: sinon.stub().resolves() };
      sinon
        .stub(getOwner(this).lookup("service:store"), "find")
        .resolves(this.post);
      this.closeModal = sinon.spy();
    });

    async function renderModal(context, event) {
      const model = { event };
      const closeModal = context.closeModal;

      await render(
        <template>
          <PostEventRecording
            @closeModal={{closeModal}}
            @inline={{true}}
            @model={{model}}
          />
        </template>
      );
    }

    test("adds the recording to the event without touching the rest", async function (assert) {
      await renderModal(this, { id: 42 });

      assert.dom(".d-modal__title-text").hasText("Add recording");
      assert.dom(".form-kit__button.--danger").doesNotExist();

      await fillIn("[name='recordingUrl']", "https://youtu.be/abc");
      await click(".form-kit__button[type='submit']");

      const { raw, edit_reason } = this.post.save.firstCall.args[0];
      assert.true(raw.includes("recording=https://youtu.be/abc"));
      assert.true(raw.includes("Description\n[/event]\n\nCome along!"));
      assert.true(raw.includes("location=https://www.youtube.com/live/abc"));
      assert.strictEqual(edit_reason, "Recording link updated");
      assert.true(this.closeModal.calledOnce);
    });

    test("edits or removes an existing recording", async function (assert) {
      this.post.raw = RAW.replace(
        'status="public"',
        'status="public" recording="https://youtu.be/old"'
      );
      await renderModal(this, { id: 42, recordingUrl: "https://youtu.be/old" });

      assert.dom(".d-modal__title-text").hasText("Edit recording");
      assert.dom("[name='recordingUrl']").hasValue("https://youtu.be/old");

      await click(".form-kit__button.--danger");

      const { raw } = this.post.save.firstCall.args[0];
      assert.false(raw.includes("recording="));
      assert.true(raw.includes("status=public"));
    });

    test("requires a web address", async function (assert) {
      await renderModal(this, { id: 42 });

      await fillIn("[name='recordingUrl']", "not a link");
      await click(".form-kit__button[type='submit']");

      assert.false(this.post.save.called);
    });
  }
);
