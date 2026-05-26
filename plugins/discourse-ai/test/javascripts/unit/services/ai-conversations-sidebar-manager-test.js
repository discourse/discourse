import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { AI_CONVERSATIONS_PANEL } from "discourse/plugins/discourse-ai/discourse/services/ai-conversations-sidebar-manager";

module("Unit | Service | ai-conversations-sidebar-manager", function (hooks) {
  setupTest(hooks);

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
    service.siteSettings.enable_ai_bot_starred_conversations = true;
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
