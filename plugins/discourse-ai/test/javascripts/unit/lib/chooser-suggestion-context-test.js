import { setOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { chooserSuggestionContext } from "discourse/plugins/discourse-ai/discourse/lib/chooser-suggestion-context";

module("Unit | Lib | chooser-suggestion-context", function (hooks) {
  setupTest(hooks);

  test("uses a new topic title when suggesting a category", function (assert) {
    this.owner.register(
      "service:composer",
      {
        model: {
          title: "How do I catch a Pokémon?",
          reply: "",
        },
      },
      { instantiate: false }
    );

    const component = {
      element: {
        closest: (selector) => selector === "#reply-control",
      },
    };
    setOwner(component, this.owner);

    const context = chooserSuggestionContext(component);

    assert.true(
      context.categoryAvailable,
      "category suggestions are available"
    );
    assert.deepEqual(
      context.categoryRequestData(),
      { text: "How do I catch a Pokémon?" },
      "the title is sent for categorization"
    );
  });
});
