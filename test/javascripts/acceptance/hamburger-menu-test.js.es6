import { acceptance } from "helpers/qunit-helpers";

acceptance("Hamburger Menu");

test("Toggle Menu", (assert) => {
  visit("/");
  andThen(() => {
    assert.ok(exists("#hamburger-menu.hidden"), "hidden by default");
  });

  click("#toggle-hamburger-menu");
  andThen(() => {
    assert.ok(!exists("#hamburger-menu.hidden"), "a click makes it appear");
  });

  click('#main-outlet')
  andThen(() => {
    assert.ok(exists("#hamburger-menu.hidden"), "clicking the body hides the menu");
  });

});

test("Menu Items", (assert) => {
  visit("/");
  click("#toggle-hamburger-menu");
  andThen(() => {
    assert.ok(!exists("#hamburger-menu .admin-link"), 'does not have admin link');
    assert.ok(!exists("#hamburger-menu .flagged-posts-link"), 'does not have flagged posts link');

    assert.ok(exists("#hamburger-menu .latest-topics-link"), 'last link to latest');
    assert.ok(exists("#hamburger-menu .badge-link"), 'has link to badges');
    assert.ok(exists("#hamburger-menu .user-directory-link"), 'has user directory link');
    assert.ok(exists("#hamburger-menu .faq-link"), 'has faq link');
    assert.ok(exists("#hamburger-menu .about-link"), 'has about link');
    assert.ok(exists("#hamburger-menu .categories-link"), 'has categories link');

    assert.ok(exists('#hamburger-menu .category-link'), 'has at least one category');
  });
});
