import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  avatarImg,
  avatarUrl,
  getRawAvatarSize,
  getRawSize,
  tinyAvatar,
  translateSize,
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
      "<img alt='' width='24' height='24' src='/path/to/avatar/48.png' class='avatar'>",
      "it returns the avatar html"
    );

    assert.strictEqual(
      avatarImg({
        avatarTemplate,
        size: "tiny",
        title: "evilest trout",
      }),
      "<img alt='' width='24' height='24' src='/path/to/avatar/48.png' class='avatar' title='evilest trout'>",
      "it adds a title if supplied"
    );

    assert.strictEqual(
      avatarImg({
        avatarTemplate,
        size: "tiny",
        extraClasses: "evil fish",
      }),
      "<img alt='' width='24' height='24' src='/path/to/avatar/48.png' class='avatar evil fish'>",
      "it adds extra classes if supplied"
    );

    assert.blank(
      avatarImg({ avatarTemplate: "", size: "tiny" }),
      "it doesn't render avatars for invalid avatar template"
    );

    assert.strictEqual(
      avatarImg({
        avatarTemplate,
        size: "tiny",
        alt: "evilest trout",
      }),
      "<img alt='evilest trout' width='24' height='24' src='/path/to/avatar/48.png' class='avatar'>",
      "it sets alt text if supplied"
    );

    assert.strictEqual(
      avatarImg({
        avatarTemplate,
        size: "tiny",
        alt: "<script>alert('x')</script>",
      }),
      "<img alt='&lt;script&gt;alert(&#x27;x&#x27;)&lt;/script&gt;' width='24' height='24' src='/path/to/avatar/48.png' class='avatar'>",
      "it escapes the alt text"
    );

    setDevicePixelRatio(oldRatio);
  });

  test("translateSize maps size names to pixels", function (assert) {
    assert.deepEqual(
      ["micro", "tiny", "small", "medium", "large", "extra_large", "huge"].map(
        translateSize
      ),
      [12, 24, 24, 48, 48, 96, 144]
    );
    assert.strictEqual(translateSize(30), 30, "passes numbers through");
  });

  test("getRawSize scales by the pixel ratio", function (assert) {
    const oldRatio = window.devicePixelRatio;

    try {
      setDevicePixelRatio(1);
      assert.strictEqual(getRawSize(20), 20);

      setDevicePixelRatio(1.5);
      assert.strictEqual(getRawSize(20), 40);

      setDevicePixelRatio(3);
      assert.strictEqual(getRawSize(20), 60);
    } finally {
      setDevicePixelRatio(oldRatio);
    }
  });

  test("avatarUrl and avatarImg use a custom getURL", function (assert) {
    const customGetURL = (path) => `https://gadget.example.com${path}`;
    const template = "/fake/template/{size}.png";
    const rawSize = getRawAvatarSize(48);

    assert.strictEqual(
      avatarUrl(template, "large", { customGetURL }),
      `https://gadget.example.com/fake/template/${rawSize}.png`
    );
    assert.true(
      avatarImg(
        { avatarTemplate: template, size: "large" },
        customGetURL
      ).includes(
        `src='https://gadget.example.com/fake/template/${rawSize}.png'`
      )
    );
  });

  test("avatarImg sets the loading attribute", function (assert) {
    assert.true(
      avatarImg({
        avatarTemplate: "/path/{size}.png",
        size: "tiny",
        loading: "lazy",
      }).endsWith(" loading='lazy'>")
    );
  });

  test("tinyAvatar renders a tiny avatar with extra options", function (assert) {
    const html = tinyAvatar("/path/{size}.png", { title: "gizmo" });

    assert.true(html.includes("width='24' height='24'"));
    assert.true(html.includes("title='gizmo'"));
    assert.true(
      tinyAvatar("/path/{size}.png", { size: "huge" }).includes("width='144'"),
      "the options override the size"
    );
  });
});
