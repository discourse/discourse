import { acceptance } from "helpers/qunit-helpers";

acceptance("Hamburger Menu");

test("Toggle Menu", (assert) => {
  visit("/");
  andThen(() => {
    assert.ok(exists("#hamburger-menu.slideright"), "hidden by default");
  });

  click("#toggle-hamburger-menu");
  andThen(() => {
    assert.ok(!exists("#hamburger-menu.slideright"), "a click makes it appear");
  });

  click(".close-hamburger");
  andThen(() => {
    assert.ok(exists("#hamburger-menu.slideright"), "clicking the X hides it");
  });
});

test("Menu Items", (assert) => {
  visit("/");
  click("#toggle-hamburger-menu");
  andThen(() => {
    assert.ok(!exists("#hamburger-menu .admin-link"));
    assert.ok(!exists("#hamburger-menu .flagged-posts-link"));

    assert.ok(exists("#hamburger-menu .latest-topics-link"));
    assert.ok(exists("#hamburger-menu .badge-link"));
    assert.ok(exists("#hamburger-menu .user-directory-link"));
    assert.ok(exists("#hamburger-menu .keyboard-shortcuts-link"));
    assert.ok(exists("#hamburger-menu .faq-link"));
    assert.ok(exists("#hamburger-menu .about-link"));
    assert.ok(exists("#hamburger-menu .categories-link"));

    assert.ok(exists('#hamburger-menu .category-link'));
  });
});
