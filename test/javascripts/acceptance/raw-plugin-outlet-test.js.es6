import { acceptance } from "helpers/qunit-helpers";

const CONNECTOR = 'javascripts/raw-test/connectors/topic-list-before-status/lala';
acceptance("Raw Plugin Outlet", {
  setup() {
    Discourse.RAW_TEMPLATES[CONNECTOR] = Handlebars.compile(
      `<span class='topic-lala'>{{context.topic.id}}</span>`
    );
  },

  teardown() {
    delete Discourse.RAW_TEMPLATES[CONNECTOR];
  }
});

test("Renders the raw plugin outlet", assert => {
  visit("/");
  andThen(() => {
    assert.ok(find('.topic-lala').length > 0, 'it renders the outlet');
    assert.equal(find('.topic-lala:eq(0)').text(), '11557', 'it has the topic id');
  });
});
