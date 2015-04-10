import { acceptance } from "helpers/qunit-helpers";

acceptance("Queued Posts", { loggedIn: true });

test("approve a post", () => {
  visit("/queued-posts");

  andThen(() => {
    ok(exists('.queued-post'), 'it has posts listed');
  });

  click('.queued-post:eq(0) button.approve');
  andThen(() => {
    ok(!exists('.queued-post'), 'it removes the post');
  });
});

test("reject a post", () => {
  visit("/queued-posts");

  andThen(() => {
    ok(exists('.queued-post'), 'it has posts listed');
  });

  click('.queued-post:eq(0) button.reject');
  andThen(() => {
    ok(!exists('.queued-post'), 'it removes the post');
  });
});
