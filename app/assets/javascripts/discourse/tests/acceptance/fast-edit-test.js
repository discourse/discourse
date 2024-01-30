import { click, fillIn, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import postFixtures from "discourse/tests/fixtures/post";
import {
  acceptance,
  metaModifier,
  query,
  selectText,
} from "discourse/tests/helpers/qunit-helpers";
import { cloneJSON } from "discourse-common/lib/object";

acceptance("Fast Edit", function (needs) {
  needs.user();
  needs.settings({
    enable_fast_edit: true,
  });
  needs.pretender((server, helper) => {
    server.get("/posts/419", () => {
      return helper.response(cloneJSON(postFixtures["/posts/398"]));
    });
  });

  test("Fast edit button works", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const textNode = query("#post_1 .cooked p").childNodes[0];

    await selectText(textNode, 9);
    await click(".quote-button .quote-edit-label");

    assert.dom("#fast-edit-input").exists();
    assert
      .dom("#fast-edit-input")
      .hasValue("Any plans", "contains selected text");

    await fillIn("#fast-edit-input", "My edit");
    await click(".save-fast-edit");

    assert.dom("#fast-edit-input").doesNotExist();
  });

  test("Works with keyboard shortcut", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const textNode = query("#post_1 .cooked p").childNodes[0];

    await selectText(textNode, 9);

    assert.dom(".quote-button").exists();

    await triggerKeyEvent(document, "keypress", "E");

    assert.dom("#fast-edit-input").exists();
    assert
      .dom("#fast-edit-input")
      .hasValue("Any plans", "contains selected text");

    // Saving
    await fillIn("#fast-edit-input", "My edit");
    await triggerKeyEvent("#fast-edit-input", "keydown", "Enter", metaModifier);

    assert.dom("#fast-edit-input").doesNotExist();

    // Closing
    await selectText(textNode, 9);

    assert.dom(".quote-button").exists();

    await triggerKeyEvent(document, "keypress", "E");

    assert.dom("#fast-edit-input").exists();

    await triggerKeyEvent("#fast-edit-input", "keydown", "Escape");
    assert.dom("#fast-edit-input").doesNotExist();
  });

  test("Opens full composer for multi-line selection", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const textNode = query("#post_2 .cooked");

    await selectText(textNode);
    await click(".quote-button .quote-edit-label");

    assert.dom("#fast-edit-input").doesNotExist();
    assert.dom(".d-editor-input").exists();
  });

  test("Works with diacritics in Latin languages", async function (assert) {
    await visit("/t/internationalization-localization/280");

    // French
    query("#post_2 .cooked").append(
      `Je suis désolé, ”comment ça va”? A bientôt!`
    );
    let textNode = query("#post_2 .cooked").childNodes[2];

    await selectText(textNode);
    await click(".quote-button .quote-edit-label");

    assert.dom("#fast-edit-input").exists();

    // exit fast edit and remove the text node
    await triggerKeyEvent("#fast-edit-input", "keydown", "Escape");
    query("#post_2 .cooked").childNodes[2].remove();

    // Spanish
    query("#post_2 .cooked").append(`Lo siento, ”¿cómo estás”? ¡Hasta pronto!`);
    textNode = query("#post_2 .cooked").childNodes[2];

    await selectText(textNode);
    await click(".quote-button .quote-edit-label");

    assert.dom("#fast-edit-input").exists();

    await triggerKeyEvent("#fast-edit-input", "keydown", "Escape");
    query("#post_2 .cooked").childNodes[2].remove();

    // Vietnamese
    query("#post_2 .cooked").append(
      `Tôi là người Việt Nam. Tôi yêu đất nước tôi. Tôi yêu quê hương tôi. Tôi yêu gia đình tôi.`
    );
    textNode = query("#post_2 .cooked").childNodes[2];

    await selectText(textNode);
    await click(".quote-button .quote-edit-label");

    assert.dom("#fast-edit-input").exists();
  });

  test("Works with CJK Ranges (Chinese, Japanese, Korean etc)", async function (assert) {
    await visit("/t/internationalization-localization/280");

    // Chinese (Simplified)
    query("#post_2 .cooked").append(
      `我是中国人。我爱我的祖国。我爱我的家乡。我爱我的家人。`
    );
    let textNode = query("#post_2 .cooked").childNodes[2];

    await selectText(textNode);
    await click(".quote-button .quote-edit-label");

    assert.dom("#fast-edit-input").exists();

    // exit fast edit and remove the text node
    await triggerKeyEvent("#fast-edit-input", "keydown", "Escape");
    query("#post_2 .cooked").childNodes[2].remove();

    // Chinese (Traditional)
    query("#post_2 .cooked").append(
      `我是中國人。我愛我的祖國。我愛我的家鄉。我愛我的家人。`
    );
    textNode = query("#post_2 .cooked").childNodes[2];

    await selectText(textNode);
    await click(".quote-button .quote-edit-label");

    assert.dom("#fast-edit-input").exists();

    await triggerKeyEvent("#fast-edit-input", "keydown", "Escape");
    query("#post_2 .cooked").childNodes[2].remove();

    // Japanese
    query("#post_2 .cooked").append(`日本語の文章を入力してください。`);
    textNode = query("#post_2 .cooked").childNodes[2];

    await selectText(textNode);
    await click(".quote-button .quote-edit-label");

    assert.dom("#fast-edit-input").exists();

    await triggerKeyEvent("#fast-edit-input", "keydown", "Escape");
    query("#post_2 .cooked").childNodes[2].remove();

    // Korean
    query("#post_2 .cooked").append(
      `국민경제의 발전을 위한 중요정책의 수립에 관하여 대통령의 자문에 응하기 위하여 국민경제자문회의를 둘 수 있다.`
    );
    textNode = query("#post_2 .cooked").childNodes[2];

    await selectText(textNode);
    await click(".quote-button .quote-edit-label");

    assert.dom("#fast-edit-input").exists();

    await triggerKeyEvent("#fast-edit-input", "keydown", "Escape");
    query("#post_2 .cooked").childNodes[2].remove();

    // Greek
    query("#post_2 .cooked").append(
      `Λορεμ ιπσθμ δολορ σιτ αμετ, μει ιδ νοvθμ φαβελλασ πετεντιθμ vελ νε, ατ νισλ σονετ οπορτερε εθμ. Αλιι δοcτθσ μει ιδ, νο αθτεμ αθδιρε ιντερεσσετ μελ, δοcενδι cομμθνε οπορτεατ τε cθμ.`
    );

    textNode = query("#post_2 .cooked").childNodes[2];

    await selectText(textNode);
    await click(".quote-button .quote-edit-label");

    assert.dom("#fast-edit-input").exists();
  });
});
