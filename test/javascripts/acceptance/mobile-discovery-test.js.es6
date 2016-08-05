import { acceptance } from "helpers/qunit-helpers";
acceptance("Topic Discovery - Mobile", { mobileView: true });

test("Visit Discovery Pages", () => {
  visit("/");
  andThen(() => {
    ok(exists(".topic-list"), "The list of topics was rendered");
    ok(exists('.topic-list .topic-list-item'), "has topics");
  });

  visit("/categories");
  andThen(() => {
    ok(exists('.category'), "has a list of categories");
  });
});
