import { settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  getExtensions,
  registerRichEditorExtension,
} from "discourse/lib/composer/rich-editor-extensions";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  setupRichEditor,
  testMarkdown,
} from "discourse/tests/helpers/rich-editor-helper";
import DiscoursePostEventOneboxNodeView from "discourse/plugins/discourse-events/discourse/components/discourse-post-event/onebox-node-view";

module("Integration | Component | RichEditorExtension", function (hooks) {
  setupRenderingTest(hooks);

  const oneboxExtension = {
    nodeViews: {
      onebox: { component: DiscoursePostEventOneboxNodeView },
    },
  };

  hooks.afterEach(function () {
    const extensions = getExtensions();
    const index = extensions.indexOf(oneboxExtension);
    if (index !== -1) {
      extensions.splice(index, 1);
    }
  });

  test("non-event topic previews collapse HTML whitespace", async function (assert) {
    registerRichEditorExtension(oneboxExtension);
    sinon
      .stub(
        this.owner.lookup("service:discourse-post-event-api"),
        "cachedEventByTopicId"
      )
      .resolves(null);

    const [editor] = await setupRichEditor(assert, "Editable text");
    const { view } = editor;
    const url = `${window.location.origin}/t/ordinary-topic/123`;
    const onebox = view.state.schema.nodes.onebox.create({
      url,
      html: `
        <aside class="quote" data-topic="123" data-post="1">
          <div class="title">Ordinary topic</div>
          <blockquote>
            Preview text
          </blockquote>
        </aside>
      `,
    });
    view.dispatch(view.state.tr.insert(0, onebox));
    await settled();

    assert
      .dom(".composer-onebox-node aside.quote")
      .hasText("Ordinary topic Preview text");
    assert
      .dom(".composer-onebox-node aside.quote")
      .hasStyle({ whiteSpace: "normal" });
    assert.dom(".ProseMirror > p").hasStyle({ whiteSpace: "break-spaces" });
    assert.strictEqual(editor.value, `${url}\n\nEditable text`);
  });

  const testCases = {
    "event alone": [
      [
        `[event start="2025-03-21 15:41" status="public" timezone="Europe/Paris"]\n[/event]\n`,
        (assert) => {
          assert
            .dom(".composer-event-node")
            .exists("Event node should be rendered");
          assert
            .dom(".composer-event__status")
            .hasText("Public", "Status should be displayed");
          assert
            .dom(".composer-event__date-display")
            .exists("Date should be displayed");
        },
        `[event start="2025-03-21 15:41" status=public timezone=Europe/Paris]\n[/event]\n`,
      ],
    ],
    "event with content around": [
      [
        `Hello world\n\n[event start="2025-03-21 15:41" status="public" timezone="Europe/Paris"]\n[/event]\nGoodbye world`,
        (assert) => {
          assert
            .dom("p")
            .exists({ count: 2 }, "Should have paragraphs around event");
          assert
            .dom(".composer-event-node")
            .exists("Event node should be rendered");
          assert
            .dom(".composer-event__status")
            .hasText("Public", "Status should be displayed");
        },
        `Hello world\n\n[event start="2025-03-21 15:41" status=public timezone=Europe/Paris]\n[/event]\nGoodbye world`,
      ],
    ],
    "event with content inside": [
      [
        `[event start="2025-03-21 15:41" status="public" timezone="Europe/Paris"]\ntest\n[/event]\n`,
        (assert) => {
          assert
            .dom(".composer-event-node")
            .exists("Event node should be rendered");
          assert
            .dom(".composer-event__status")
            .hasText("Public", "Status should be displayed");
        },
        `[event start="2025-03-21 15:41" status=public timezone=Europe/Paris]\ntest\n\n[/event]\n`,
      ],
    ],
  };

  Object.entries(testCases).forEach(([name, tests]) => {
    tests.forEach(([markdown, expectedHtml, expectedMarkdown]) => {
      test(name, async function (assert) {
        await testMarkdown(assert, markdown, expectedHtml, expectedMarkdown);
      });
    });
  });

  test("event preserves allowed custom fields", async function (assert) {
    this.siteSettings.discourse_post_event_allowed_custom_fields =
      "fancy_field";

    await testMarkdown(
      assert,
      `[event start="2025-03-21 15:41" status="public" timezone="Europe/Paris" fancyField="hello world"]\n[/event]\n`,
      (a) => {
        a.dom(".composer-event-node").exists("Event node should be rendered");
      },
      `[event start="2025-03-21 15:41" status=public timezone=Europe/Paris fancyField="hello world"]\n[/event]\n`
    );
  });

  test("event preserves url through a round trip", async function (assert) {
    await testMarkdown(
      assert,
      `[event start="2025-03-21 15:41" status="public" timezone="Europe/Paris" location="meet.example.com/new" url="https://meet.example.com/old"]\n[/event]\n`,
      (a) => {
        a.dom(".composer-event-node").exists("Event node should be rendered");
      },
      `[event start="2025-03-21 15:41" location=meet.example.com/new url=https://meet.example.com/old status=public timezone=Europe/Paris]\n[/event]\n`
    );
  });

  test("event preserves custom fields with uppercase letters", async function (assert) {
    this.siteSettings.discourse_post_event_allowed_custom_fields = "dress_CODE";

    await testMarkdown(
      assert,
      `[event start="2025-03-21 15:41" status="public" timezone="Europe/Paris" dressCode="black tie"]\n[/event]\n`,
      (a) => {
        a.dom(".composer-event-node").exists("Event node should be rendered");
      },
      `[event start="2025-03-21 15:41" status=public timezone=Europe/Paris dressCode="black tie"]\n[/event]\n`
    );
  });
});
