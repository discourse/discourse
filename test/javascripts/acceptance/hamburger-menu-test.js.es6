import { acceptance } from "helpers/qunit-helpers";

acceptance("Hamburger Menu");

test("Menu Items", (assert) => {
  visit("/");
  click("#toggle-hamburger-menu");
  andThen(() => {
    assert.ok(!exists(".hamburger-panel .admin-link"), 'does not have admin link');
    assert.ok(!exists(".hamburger-panel .flagged-posts-link"), 'does not have flagged posts link');

    assert.ok(exists(".hamburger-panel .latest-topics-link"), 'last link to latest');
    assert.ok(exists(".hamburger-panel .badge-link"), 'has link to badges');
    assert.ok(exists(".hamburger-panel .user-directory-link"), 'has user directory link');
    assert.ok(exists(".hamburger-panel .faq-link"), 'has faq link');
    assert.ok(exists(".hamburger-panel .about-link"), 'has about link');
    assert.ok(exists(".hamburger-panel .categories-link"), 'has categories link');

    assert.ok(exists('.hamburger-panel .category-link'), 'has at least one category');
  });
});
