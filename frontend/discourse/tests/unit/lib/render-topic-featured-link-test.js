import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import renderTopicFeaturedLink from "discourse/lib/render-topic-featured-link";

function buildTopic(featuredLink, domain) {
  return {
    get(key) {
      if (key === "featured_link") {
        return featuredLink;
      }
      if (key === "featured_link_root_domain") {
        return domain;
      }
    },
    siteSettings: { exclude_rel_nofollow_domains: "" },
  };
}

module("Unit | Utility | render-topic-featured-link", function (hooks) {
  setupTest(hooks);

  test("escapes a featured link containing quotes so it cannot inject attributes", function (assert) {
    const topic = buildTopic(
      'https://example.com/?"onclick="alert(document.cookie)"',
      "example.com"
    );

    const div = document.createElement("div");
    div.innerHTML = renderTopicFeaturedLink(topic);
    const link = div.querySelector("a.topic-featured-link");

    assert
      .dom(link)
      .doesNotHaveAttribute("onclick", "does not inject an onclick handler");
    assert
      .dom(link)
      .hasAttribute(
        "href",
        'https://example.com/?"onclick="alert(document.cookie)"',
        "keeps the link target as a single href value"
      );
    assert
      .dom(link)
      .containsText("example.com", "still renders the domain text");
  });
});
