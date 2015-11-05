import { acceptance } from "helpers/qunit-helpers";

acceptance("Badges");

test("Visit Badge Pages", () => {
  visit("/badges");
  andThen(() => {
    ok(exists('.badges-listing tr'), "has a list of badges");
  });

  visit("/badges/9/autobiographer");
  andThen(() => {
    ok(exists('.badges-listing div'), "has the badge in the listing");
    ok(exists('.badge-user'), "has the list of users with that badge");
  });
});
