import { acceptance } from "helpers/qunit-helpers";

acceptance("Queued Posts", { loggedIn: true });

test("approve a post", () => {
  visit("/queued-posts");

  click('.queued-post:eq(0) button.approve');
  andThen(() => {
    ok(!exists('.queued-post'), 'it removes the post');
  });
});

test("reject a post", () => {
  visit("/queued-posts");

  click('.queued-post:eq(0) button.reject');
  andThen(() => {
    ok(!exists('.queued-post'), 'it removes the post');
  });
});

test("delete user", () => {
  visit("/queued-posts");

  click('.queued-post:eq(0) button.delete-user');
  andThen(() => {
    ok(exists('.bootbox.modal'), 'it pops up a confirmation dialog');
  });

  click('.modal-footer a:eq(1)');
  andThen(() => {
    ok(!exists('.bootbox.modal'), 'it dismisses the modal');
    ok(exists('.queued-post'), "it doesn't remove the post");
  });

  click('.queued-post:eq(0) button.delete-user');
  click('.modal-footer a:eq(0)');
  andThen(() => {
    ok(!exists('.bootbox.modal'), 'it dismisses the modal');
    ok(!exists('.queued-post'), "it removes the post");
  });
});

test("edit a post - cancel", () => {
  visit("/queued-posts");

  click('.queued-post:eq(0) button.edit');
  andThen(() => {
    equal(find('.queued-post:eq(0) textarea').val(), 'queued post text', 'it shows an editor');
  });

  fillIn('.queued-post:eq(0) textarea', 'new post text');
  click('.queued-post:eq(0) button.cancel');
  andThen(() => {
    ok(!exists('textarea'), 'it disables editing');
    equal(find('.queued-post:eq(0) .body p').text(), 'queued post text', 'it reverts the new text');
  });
});

test("edit a post - confirm", () => {
  visit("/queued-posts");

  click('.queued-post:eq(0) button.edit');
  andThen(() => {
    equal(find('.queued-post:eq(0) textarea').val(), 'queued post text', 'it shows an editor');
  });

  fillIn('.queued-post:eq(0) textarea', 'new post text');
  click('.queued-post:eq(0) button.confirm');
  andThen(() => {
    ok(!exists('textarea'), 'it disables editing');
    equal(find('.queued-post:eq(0) .body p').text(), 'new post text', 'it has the new text');
  });
});
