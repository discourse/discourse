import { acceptance } from "helpers/qunit-helpers";

acceptance("Badges");

test("Visit Badge Pages", () => {
  visit("/badges");
  andThen(() => {
    ok($('body.badges-page').length, "has body class");
    ok(exists('.badge-groups .badge-card'), "has a list of badges");
  });

  visit("/badges/9/autobiographer");
  andThen(() => {
    ok(exists('.badge-card'), "has the badge in the listing");
    ok(exists('.user-info'), "has the list of users with that badge");
    ok(!exists('.badge-card:eq(0) script'));
  });
});
