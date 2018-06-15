import { acceptance } from "helpers/qunit-helpers";

acceptance("CustomHTML template", {
  beforeEach() {
    Ember.TEMPLATES["top"] = Ember.HTMLBars.compile(
      `<span class='top-span'>TOP</span>`
    );
  },

  afterEach() {
    delete Ember.TEMPLATES["top"];
  }
});

QUnit.test("renders custom template", assert => {
  visit("/static/faq");
  andThen(() => {
    assert.equal(
      find("span.top-span").text(),
      "TOP",
      "it inserted the template"
    );
  });
});
