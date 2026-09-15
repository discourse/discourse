import Service from "@ember/service";
import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import VoiceInviteAgentModal from "discourse/plugins/voice/discourse/components/modal/voice-invite-agent";
import VoiceInviteAgentButton from "discourse/plugins/voice/discourse/components/voice-invite-agent-button";

class ModalStub extends Service {
  show(component, options) {
    this.component = component;
    this.model = options.model;
  }
}

module("Integration | Component | VoiceInviteAgentButton", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    logIn(this.owner);
    this.owner.unregister("service:modal");
    this.owner.register("service:modal", ModalStub);
    this.owner.lookup("service:site").set("voice_livekit_agent_bot_id", -2);
    this.room = {
      id: 1,
      public: true,
      expected_transport: "livekit",
      active_participants: [{ id: 42 }],
    };
  });

  test("opens the agent chooser for this room", async function (assert) {
    await render(
      <template>
        <DDropdownMenu as |dropdown|>
          <VoiceInviteAgentButton @item={{dropdown.item}} @room={{this.room}} />
        </DDropdownMenu>
      </template>
    );
    await click(".voice-invite-agent");
    const modal = this.owner.lookup("service:modal");
    assert.strictEqual(modal.component, VoiceInviteAgentModal);
    assert.strictEqual(modal.model.room, this.room);
  });

  test("submits an agent picked from the deployed list", async function (assert) {
    let invited = false;
    this.model = { room: this.room };
    this.closeModal = () => {
      this.closed = true;
    };
    pretender.get("/voice/agents", () =>
      response(200, { agents: [{ name: "assistant" }, { name: "support" }] })
    );
    pretender.post("/voice/rooms/1/invite_agent", (request) => {
      invited = true;
      assert.strictEqual(request.requestBody, "agent_name=assistant");
      return response(201, { dispatch_id: "AD_test" });
    });
    await render(
      <template>
        <VoiceInviteAgentModal
          @closeModal={{this.closeModal}}
          @inline={{true}}
          @model={{this.model}}
        />
      </template>
    );
    assert.dom("[data-name='agent_name'] input").doesNotExist();
    await formKit().field("agent_name").select("assistant");
    await click("button[type='submit']");
    assert.true(invited);
    assert.true(this.closed);
  });

  test("lets the inviter type a name instead of picking one", async function (assert) {
    let invited = false;
    this.model = { room: this.room };
    this.closeModal = () => {};
    pretender.get("/voice/agents", () =>
      response(200, { agents: [{ name: "assistant" }] })
    );
    pretender.post("/voice/rooms/1/invite_agent", (request) => {
      invited = true;
      assert.strictEqual(request.requestBody, "agent_name=custom-agent");
      return response(201, { dispatch_id: "AD_test" });
    });
    await render(
      <template>
        <VoiceInviteAgentModal
          @closeModal={{this.closeModal}}
          @inline={{true}}
          @model={{this.model}}
        />
      </template>
    );
    await click(".voice-invite-agent__toggle");
    assert.dom("[data-name='agent_name'] select").doesNotExist();
    await fillIn("[data-name='agent_name'] input", "custom-agent");
    await click("button[type='submit']");
    assert.true(invited);
  });

  test("falls back to a typed name when the list is unavailable", async function (assert) {
    this.model = { room: this.room };
    pretender.get("/voice/agents", () => response(503, { errors: ["down"] }));
    await render(
      <template>
        <VoiceInviteAgentModal
          @closeModal={{this.closeModal}}
          @inline={{true}}
          @model={{this.model}}
        />
      </template>
    );
    assert.dom("[data-name='agent_name'] input").exists();
    assert.dom("[data-name='agent_name'] select").doesNotExist();
  });

  test("submits a typed agent name when none are listed", async function (assert) {
    let invited = false;
    this.model = { room: this.room };
    this.closeModal = () => {
      this.closed = true;
    };
    pretender.get("/voice/agents", () => response(200, { agents: [] }));
    pretender.post("/voice/rooms/1/invite_agent", (request) => {
      invited = true;
      assert.strictEqual(request.requestBody, "agent_name=assistant");
      return response(201, { dispatch_id: "AD_test" });
    });
    await render(
      <template>
        <VoiceInviteAgentModal
          @closeModal={{this.closeModal}}
          @inline={{true}}
          @model={{this.model}}
        />
      </template>
    );
    await fillIn("[data-name='agent_name'] input", "assistant");
    await click("button[type='submit']");
    assert.true(invited);
    assert.true(this.closed);
  });

  test("hides the action outside eligible calls", async function (assert) {
    for (const changes of [
      { public: false },
      { expected_transport: "mesh" },
      { active_participants: [] },
      { active_participants: [{ id: 42 }, { id: -2 }] },
    ]) {
      this.set("testRoom", { ...this.room, ...changes });
      await render(
        <template>
          <DDropdownMenu as |dropdown|>
            <VoiceInviteAgentButton
              @item={{dropdown.item}}
              @room={{this.testRoom}}
            />
          </DDropdownMenu>
        </template>
      );
      assert.dom(".voice-invite-agent").doesNotExist();
    }
  });

  test("requires an available bot the user may invite", async function (assert) {
    this.owner.lookup("service:site").set("voice_livekit_agent_bot_id", null);
    await render(
      <template>
        <DDropdownMenu as |dropdown|>
          <VoiceInviteAgentButton @item={{dropdown.item}} @room={{this.room}} />
        </DDropdownMenu>
      </template>
    );
    assert.dom(".voice-invite-agent").doesNotExist();
  });
});
