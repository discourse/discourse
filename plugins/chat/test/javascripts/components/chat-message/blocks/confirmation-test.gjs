import { click, find, findAll, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import Block from "discourse/plugins/chat/discourse/components/chat-message/blocks/block";

module("Component | ChatMessage | Blocks | Confirmation", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a confirmation card and submits either answer", async function (assert) {
    this.definition = {
      type: "confirmation",
      title: "Edit category",
      cooked_question: "<p>Do you want to make this change?</p>",
      parameters: [
        { label: "value", value: "<script>alert('test')</script>" },
        { label: "color", value: "4CBB17" },
      ],
      elements: [
        { type: "button", action_id: "approve", text: { text: "Yes" } },
        { type: "button", action_id: "reject", text: { text: "No" } },
      ],
    };
    this.cooked =
      "<p>Changing <code>name</code> from Storm → Wind &amp; Rain</p>";
    const interactions = [];
    this.createInteraction = (id) => interactions.push(id);

    await render(
      <template>
        <Block
          @cooked={{this.cooked}}
          @createInteraction={{this.createInteraction}}
          @definition={{this.definition}}
        />
      </template>
    );

    assert
      .dom(".chat-confirmation__title")
      .hasText("Edit category", "shows the action title");
    assert
      .dom(".chat-confirmation__description code")
      .includesText("name", "formats the changed field");
    assert
      .dom(".chat-confirmation__description")
      .includesText("Wind & Rain", "shows the proposed name");
    assert
      .dom(".chat-confirmation__parameters dd:first-of-type")
      .hasText(
        this.definition.parameters[0].value,
        "shows parameter values as text"
      );
    assert
      .dom(".chat-confirmation script")
      .doesNotExist("escapes parameter markup");
    assert
      .dom(".chat-confirmation__footer")
      .includesText(
        "Do you want to make this change?",
        "asks for confirmation"
      );

    assert.dom(".chat-confirmation__color").exists();
    assert.strictEqual(
      getComputedStyle(document.querySelector(".chat-confirmation__color"))
        .backgroundColor,
      "rgb(76, 187, 23)",
      "shows the proposed color"
    );

    const swatchWidth = document
      .querySelector(".chat-confirmation__color")
      .getBoundingClientRect().width;
    for (const section of ["title", "description"]) {
      const sectionWidth = document
        .querySelector(`.chat-confirmation__${section}`)
        .getBoundingClientRect().width;
      assert.true(
        sectionWidth > swatchWidth * 5,
        `${section} retains the card width rather than the swatch width`
      );
    }

    await click("#approve");
    await click("#reject");

    assert.deepEqual(
      interactions,
      ["approve", "reject"],
      "sends the corresponding action for each answer"
    );
  });

  test("renders escaped diffs with a category heading and retains them after approval", async function (assert) {
    this.definition = {
      type: "confirmation",
      title: "Editing category: Cool Stuff",
      cooked_title:
        '<p>Editing category: <a class="hashtag-cooked" data-type="category">Cool Stuff</a></p>',
      cooked_question: "<p>Do you want to make this change?</p>",
      changes: [
        { label: "Changing name:", before: "Cool Stuff", after: "Neat stuff" },
        {
          label: "Changing color:",
          before: "0088CC",
          after: "4CBB17",
          before_color: "0088CC",
          after_color: "4CBB17",
        },
        {
          label: "Changing description:",
          before: "Old description",
          after: "<script>alert('test')</script>\nNew description",
        },
      ],
      parameters: [],
      elements: [
        { type: "button", action_id: "approve", text: { text: "Yes" } },
      ],
    };
    this.cooked = "<p>Legacy description</p>";

    await render(
      <template>
        <Block @cooked={{this.cooked}} @definition={{this.definition}} />
      </template>
    );

    assert
      .dom(".chat-confirmation__title .hashtag-cooked")
      .hasText("Cool Stuff", "renders the category in the heading");
    assert
      .dom(".chat-confirmation__change-label")
      .hasText("Changing name:", "uses the smaller field label");
    assert
      .dom(".chat-confirmation__before")
      .hasText("Cool Stuff", "strikes through the current value");
    assert
      .dom(".chat-confirmation__after")
      .hasText("Neat stuff", "shows the proposed value");
    assert
      .dom(".chat-confirmation script")
      .doesNotExist("escapes values rather than rendering their markup");
    assert.strictEqual(
      find(".chat-confirmation__before .chat-confirmation__diff-value")
        .textContent,
      "Cool Stuff",
      "preserves only the value, without template indentation"
    );
    const proposedValues = findAll(
      ".chat-confirmation__after .chat-confirmation__diff-value"
    );
    assert.strictEqual(
      proposedValues[2].textContent,
      this.definition.changes[2].after,
      "preserves intentional description line breaks"
    );
    const before = find(".chat-confirmation__before");
    assert.true(
      before.getBoundingClientRect().height <
        parseFloat(getComputedStyle(before).fontSize) * 2,
      "single-line names remain compact"
    );
    assert
      .dom(".chat-confirmation")
      .doesNotIncludeText(
        "Legacy description",
        "avoids duplicating the diff in the message body"
      );

    assert
      .dom(".chat-confirmation__diff .chat-confirmation__color")
      .exists({ count: 2 }, "previews the old and proposed colors");

    this.set("definition", {
      ...this.definition,
      cooked_status: "<p>Approved by jordan.</p>",
      elements: [],
    });
    await settled();
    assert
      .dom(".chat-confirmation__diff")
      .exists({ count: 3 }, "preserves each diff after approval");
    assert
      .dom(".chat-confirmation__footer")
      .hasText("Approved by jordan.", "replaces the question with the outcome");
    assert
      .dom(".chat-confirmation button")
      .doesNotExist("removes resolved actions");
  });

  test("omits a creation card's middle section unless there are properties or an error", async function (assert) {
    this.definition = {
      title: "Create tag: dingle-dots",
      type: "confirmation",
      show_description: false,
      cooked_title: "<p>Create tag: <code>dingle-dots</code></p>",
      cooked_question: "<p>Do you want to create this tag?</p>",
      parameters: [],
      elements: [
        { type: "button", action_id: "approve", text: { text: "Yes" } },
      ],
    };
    this.cooked = "<p>Creating tag 'dingle-dots'</p>";
    await render(
      <template>
        <Block @cooked={{this.cooked}} @definition={{this.definition}} />
      </template>
    );
    assert
      .dom(".chat-confirmation__title code")
      .hasText("dingle-dots", "identifies the tag in the heading");
    assert
      .dom(".chat-confirmation__description")
      .doesNotExist("omits redundant details and empty padding");
    assert
      .dom(".chat-confirmation__footer")
      .includesText(
        "Do you want to create this tag?",
        "asks the creation question"
      );
    this.set("definition", {
      ...this.definition,
      parameters: [{ label: "description", value: "Release announcements" }],
    });
    await settled();
    assert
      .dom(".chat-confirmation__description")
      .hasText(
        "description Release announcements",
        "keeps additional properties available for review"
      );
    this.set("definition", {
      ...this.definition,
      parameters: [],
      cooked_error: "<p>Could not create tag.</p>",
    });
    await settled();
    assert
      .dom(".chat-confirmation__description")
      .hasText(
        "Could not create tag.",
        "keeps execution errors visible for retries"
      );
    this.set("definition", {
      ...this.definition,
      cooked_error: "",
      cooked_status: "<p>Approved by jordan.</p>",
      elements: [],
    });
    await settled();
    assert
      .dom(".chat-confirmation__description")
      .doesNotExist("retains the compact layout after approval");
    assert
      .dom(".chat-confirmation__footer")
      .hasText("Approved by jordan.", "shows the resolved outcome");
  });

  test("uses the shared field-label markup for a suspension duration", async function (assert) {
    this.definition = {
      type: "confirmation",
      title: "Suspend user: hannah",
      description_label: "Duration:",
      cooked_question: "<p>Do you want to suspend this user?</p>",
      parameters: [],
      elements: [],
    };
    this.cooked = "<p>5 days</p>";
    await render(
      <template>
        <Block @cooked={{this.cooked}} @definition={{this.definition}} />
      </template>
    );
    assert
      .dom(".chat-confirmation__change > .chat-confirmation__change-label")
      .hasText("Duration:", "reuses the label markup used by diffs");
    assert
      .dom(".chat-confirmation__description .chat-cooked")
      .hasText("5 days", "keeps the duration separate from the label");
    const label = find(".chat-confirmation__change-label");
    const value = find(".chat-confirmation__description .chat-cooked");
    assert.true(
      parseFloat(getComputedStyle(label).fontSize) <
        parseFloat(getComputedStyle(value).fontSize),
      "uses the shared smaller label size"
    );
    assert.strictEqual(
      getComputedStyle(label).fontWeight,
      "700",
      "uses the shared bold label weight"
    );
    assert
      .dom(".chat-confirmation__diff")
      .doesNotExist("retains the concise design without a diff");
  });

  for (const status of ["Approved by jordan.", "Rejected by jordan."]) {
    test(`keeps the card layout after ${status}`, async function (assert) {
      this.definition = {
        type: "confirmation",
        title: "Edit category",
        cooked_question: "<p>Do you want to make this change?</p>",
        cooked_status: `<p>${status}</p>`,
        parameters: [{ label: "color", value: "4CBB17", color: "4CBB17" }],
        elements: [],
      };
      this.cooked = "<p>Changing name from Storm → Wind &amp; Rain</p>";

      await render(
        <template>
          <Block @cooked={{this.cooked}} @definition={{this.definition}} />
        </template>
      );

      assert.dom(".chat-confirmation__title").hasText("Edit category");
      assert.dom(".chat-confirmation__description").includesText("Wind & Rain");
      assert.dom(".chat-confirmation__footer").hasText(status);
      assert.dom(".chat-confirmation button").doesNotExist();
      assert.dom(".chat-confirmation__color").exists();
      assert.dom(".chat-confirmation").doesNotIncludeText("Do you want");
    });
  }
});
