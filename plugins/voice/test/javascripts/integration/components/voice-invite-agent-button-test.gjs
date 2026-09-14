import Service from "@ember/service";
import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
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
    this.owner.lookup("service:current-user").set("admin", true);
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
          <VoiceInviteAgentButton @room={{this.room}} @item={{dropdown.item}} />
        </DDropdownMenu>
      </template>
    );
    await click(".voice-invite-agent");
    const modal = this.owner.lookup("service:modal");
    assert.strictEqual(modal.component, VoiceInviteAgentModal);
    assert.strictEqual(modal.model.room, this.room);
  });

  test("submits the chosen agent name", async function (assert) {
    let invited = false;
    this.model = { room: this.room };
    this.closeModal = () => {
      this.closed = true;
    };
    pretender.post("/voice/rooms/1/invite_agent", (request) => {
      invited = true;
      assert.strictEqual(request.requestBody, "agent_name=assistant");
      return response(201, { dispatch_id: "AD_test" });
    });
    await render(
      <template>
        <VoiceInviteAgentModal
          @inline={{true}}
          @model={{this.model}}
          @closeModal={{this.closeModal}}
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
              @room={{this.testRoom}}
              @item={{dropdown.item}}
            />
          </DDropdownMenu>
        </template>
      );
      assert.dom(".voice-invite-agent").doesNotExist();
    }
  });

  test("requires an admin and an available bot", async function (assert) {
    this.owner.lookup("service:current-user").set("admin", false);
    await render(
      <template>
        <DDropdownMenu as |dropdown|>
          <VoiceInviteAgentButton @room={{this.room}} @item={{dropdown.item}} />
        </DDropdownMenu>
      </template>
    );
    assert.dom(".voice-invite-agent").doesNotExist();

    this.owner.lookup("service:current-user").set("admin", true);
    this.owner.lookup("service:site").set("voice_livekit_agent_bot_id", null);
    await render(
      <template>
        <DDropdownMenu as |dropdown|>
          <VoiceInviteAgentButton @room={{this.room}} @item={{dropdown.item}} />
        </DDropdownMenu>
      </template>
    );
    assert.dom(".voice-invite-agent").doesNotExist();
  });
});
