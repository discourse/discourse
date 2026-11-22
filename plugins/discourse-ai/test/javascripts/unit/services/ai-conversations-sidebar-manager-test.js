import { getOwner } from "@ember/owner";
import { triggerEvent } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { AI_CONVERSATIONS_PANEL } from "discourse/plugins/discourse-ai/discourse/services/ai-conversations-sidebar-manager";

module("Unit | Service | ai-conversations-sidebar-manager", function (hooks) {
  setupTest(hooks);

  test("scroll pagination follows the conversation list when its DOM is replaced", async function (assert) {
    const service = getOwner(this).lookup(
      "service:ai-conversations-sidebar-manager"
    );
    const fetchMessages = sinon.stub(service, "fetchMessages").resolves();
    const list = document.createElement("div");
    list.className = "sidebar-sections ai-conversations-panel";
    document.getElementById("qunit-fixture").append(list);

    service.appEvents.trigger("discourse-ai:conversations-sidebar-updated");
    await triggerEvent(list, "scroll");
    assert.true(
      fetchMessages.calledOnce,
      "the initial list loads older conversations"
    );
    fetchMessages.resetHistory();

    const replacement = document.createElement("div");
    replacement.className = list.className;
    list.replaceWith(replacement);
    service.appEvents.trigger("discourse-ai:conversations-sidebar-updated");

    await triggerEvent(list, "scroll");
    assert.false(
      fetchMessages.called,
      "the detached list no longer loads conversations"
    );

    await triggerEvent(replacement, "scroll");
    assert.true(
      fetchMessages.calledOnce,
      "the replacement list loads older conversations"
    );
  });

  test("removes the scroll listener when the conversation list disappears", async function (assert) {
    const service = getOwner(this).lookup(
      "service:ai-conversations-sidebar-manager"
    );
    const fetchMessages = sinon.stub(service, "fetchMessages").resolves();
    const list = document.createElement("div");
    list.className = "sidebar-sections ai-conversations-panel";
    document.getElementById("qunit-fixture").append(list);
    service.appEvents.trigger("discourse-ai:conversations-sidebar-updated");

    list.remove();
    service.appEvents.trigger("discourse-ai:conversations-sidebar-updated");
    await triggerEvent(list, "scroll");

    assert.false(
      fetchMessages.called,
      "scrolling the removed list does not load conversations"
    );
  });

  test("unstarred conversations move into newly created date sections", function (assert) {
    const service = getOwner(this).lookup(
      "service:ai-conversations-sidebar-manager"
    );
    let setPanelCount = 0;
    const registeredSections = [];

    service.api = {
      addSidebarSection(callback, panel) {
        registeredSections.push({ callback, panel });
      },
    };
    Object.defineProperty(service.sidebarState, "currentPanel", {
      configurable: true,
      value: { key: AI_CONVERSATIONS_PANEL },
    });
    service.sidebarState.setPanel = (panel) => {
      setPanelCount += 1;
      assert.strictEqual(panel, AI_CONVERSATIONS_PANEL);
    };
    service.capabilities.isIpadOS = false;

    const lastPostedAt = new Date(Date.now() - 3 * 86400000).toISOString();
    const topic = {
      id: 1,
      slug: "starred-topic",
      title: "Starred topic",
      ai_conversation_starred: true,
      ai_conversation_starred_at: new Date().toISOString(),
      last_posted_at: lastPostedAt,
    };

    service.topics = [topic];
    service._rebuildSections();

    assert.false(
      service.sections.some((section) => section.name === "last-7-days"),
      "starred-only topics do not create date sections"
    );

    const setPanelCountBeforeUnstar = setPanelCount;

    service._updateTopic({
      ...topic,
      ai_conversation_starred: false,
      ai_conversation_starred_at: null,
    });

    const lastSevenDaysSection = service.sections.find(
      (section) => section.name === "last-7-days"
    );

    assert.strictEqual(
      lastSevenDaysSection?.links.length,
      1,
      "the unstarred conversation appears in its date section"
    );
    assert.strictEqual(
      lastSevenDaysSection.links[0].key,
      topic.id,
      "the date section contains the unstarred topic"
    );
    assert.true(
      registeredSections.some(
        (registeredSection) =>
          registeredSection.panel === AI_CONVERSATIONS_PANEL
      ),
      "the new section is registered with the AI conversations panel"
    );
    assert.true(
      setPanelCount > setPanelCountBeforeUnstar,
      "the sidebar panel is refreshed after registering the new section"
    );
  });
});
