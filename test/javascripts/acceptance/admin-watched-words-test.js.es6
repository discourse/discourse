import { acceptance } from "helpers/qunit-helpers";
acceptance("Admin - Watched Words", { loggedIn: true });

QUnit.test("list words in groups", assert => {
  visit("/admin/logs/watched_words/action/block");
  andThen(() => {
    assert.ok(exists(".watched-words-list"));
    assert.ok(
      !exists(".watched-words-list .watched-word"),
      "Don't show bad words by default."
    );
  });

  fillIn(".admin-controls .controls input[type=text]", "li");
  andThen(() => {
    assert.equal(
      find(".watched-words-list .watched-word").length,
      1,
      "When filtering, show words even if checkbox is unchecked."
    );
  });

  fillIn(".admin-controls .controls input[type=text]", "");
  andThen(() => {
    assert.ok(
      !exists(".watched-words-list .watched-word"),
      "Clearing the filter hides words again."
    );
  });

  click(".show-words-checkbox");
  andThen(() => {
    assert.ok(
      exists(".watched-words-list .watched-word"),
      "Always show the words when checkbox is checked."
    );
  });

  click(".nav-stacked .censor a");
  andThen(() => {
    assert.ok(exists(".watched-words-list"));
    assert.ok(!exists(".watched-words-list .watched-word"), "Empty word list.");
  });
});

QUnit.test("add words", assert => {
  visit("/admin/logs/watched_words/action/block");
  andThen(() => {
    click(".show-words-checkbox");
    fillIn(".watched-word-form input", "poutine");
  });
  click(".watched-word-form button");
  andThen(() => {
    let found = [];
    _.each(find(".watched-words-list .watched-word"), i => {
      if (
        $(i)
          .text()
          .trim() === "poutine"
      ) {
        found.push(true);
      }
    });
    assert.equal(found.length, 1);
  });
});

QUnit.test("remove words", assert => {
  visit("/admin/logs/watched_words/action/block");
  click(".show-words-checkbox");

  let word = null;
  andThen(() => {
    _.each(find(".watched-words-list .watched-word"), i => {
      if (
        $(i)
          .text()
          .trim() === "anise"
      ) {
        word = i;
      }
    });
    click("#" + $(word).attr("id"));
  });
  andThen(() => {
    assert.equal(find(".watched-words-list .watched-word").length, 1);
  });
});
