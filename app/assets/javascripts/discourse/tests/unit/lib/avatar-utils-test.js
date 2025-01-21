import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  avatarImg,
  avatarUrl,
  getRawAvatarSize,
} from "discourse/lib/avatar-utils";
import { setupURL } from "discourse/lib/get-url";

module("Unit | Utilities", function (hooks) {
  setupTest(hooks);

  test("getRawAvatarSize avoids redirects", function (assert) {
    assert.strictEqual(
      getRawAvatarSize(1),
      24,
      "returns the first size larger on the menu"
    );

    assert.strictEqual(getRawAvatarSize(2000), 288, "caps at highest");
  });

  test("avatarUrl", function (assert) {
    assert.blank(avatarUrl("", "tiny"), "no template returns blank");
    assert.strictEqual(
      avatarUrl("/fake/template/{size}.png", "tiny"),
      "/fake/template/" + getRawAvatarSize(24) + ".png",
      "simple avatar url"
    );
    assert.strictEqual(
      avatarUrl("/fake/template/{size}.png", "large"),
      "/fake/template/" + getRawAvatarSize(48) + ".png",
      "different size"
    );

    setupURL("https://app-cdn.example.com", "https://example.com", "");

    assert.strictEqual(
      avatarUrl("/fake/template/{size}.png", "large"),
      "https://app-cdn.example.com/fake/template/" +
        getRawAvatarSize(48) +
        ".png",
      "uses CDN if present"
    );
  });

  let setDevicePixelRatio = function (value) {
    if (Object.defineProperty && !window.hasOwnProperty("devicePixelRatio")) {
      Object.defineProperty(window, "devicePixelRatio", { value: 2 });
    } else {
      window.devicePixelRatio = value;
    }
  };

  test("avatarImg", function (assert) {
    let oldRatio = window.devicePixelRatio;
    setDevicePixelRatio(2);

    let avatarTemplate = "/path/to/avatar/{size}.png";
    assert.strictEqual(
      avatarImg({ avatarTemplate, size: "tiny" }),
      "<img loading='lazy' alt='' width='24' height='24' src='/path/to/avatar/48.png' class='avatar'>",
      "it returns the avatar html"
    );

    assert.strictEqual(
      avatarImg({
        avatarTemplate,
        size: "tiny",
        title: "evilest trout",
      }),
      "<img loading='lazy' alt='' width='24' height='24' src='/path/to/avatar/48.png' class='avatar' title='evilest trout'>",
      "it adds a title if supplied"
    );

    assert.strictEqual(
      avatarImg({
        avatarTemplate,
        size: "tiny",
        extraClasses: "evil fish",
      }),
      "<img loading='lazy' alt='' width='24' height='24' src='/path/to/avatar/48.png' class='avatar evil fish'>",
      "it adds extra classes if supplied"
    );

    assert.blank(
      avatarImg({ avatarTemplate: "", size: "tiny" }),
      "it doesn't render avatars for invalid avatar template"
    );

    setDevicePixelRatio(oldRatio);
  });
});
