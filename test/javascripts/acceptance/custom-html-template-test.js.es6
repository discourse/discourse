import { acceptance } from "helpers/qunit-helpers";

acceptance("CustomHTML template", {
  setup() {
    Ember.TEMPLATES['top'] = Ember.HTMLBars.compile(`<span class='top-span'>TOP</span>`);
  },

  teardown() {
    delete Ember.TEMPLATES['top'];
  }
});

test("renders custom template", assert => {
  visit("/static/faq");
  andThen(() => {
    assert.equal(find('span.top-span').text(), 'TOP', 'it inserted the template');
  });
});
