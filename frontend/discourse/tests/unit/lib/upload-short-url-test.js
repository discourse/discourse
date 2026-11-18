import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import {
  cacheShortUploadUrl,
  lookupCachedUploadUrl,
  lookupUncachedUploadUrls,
  MISSING,
  resetCache,
  resolveAllShortUrls,
  resolveCachedShortUrls,
} from "pretty-text/upload-short-url";
import { module, test } from "qunit";
import { ajax } from "discourse/lib/ajax";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { fixture } from "discourse/tests/helpers/qunit-helpers";

function stubUrls(imageSrcs, attachmentSrcs, otherMediaSrcs) {
  if (!imageSrcs) {
    imageSrcs = [
      {
        short_url: "upload://a.jpeg",
        url: "/images/avatar.png?a",
        short_path: "/uploads/short-url/a.jpeg",
      },
      {
        short_url: "upload://b.jpeg",
        url: "/images/avatar.png?b",
        short_path: "/uploads/short-url/b.jpeg",
      },
      {
        short_url: "upload://z.jpeg",
        url: "/images/avatar.png?z",
        short_path: "/uploads/short-url/z.jpeg",
      },
    ];
  }

  if (!attachmentSrcs) {
    attachmentSrcs = [
      {
        short_url: "upload://c.pdf",
        url: "/uploads/default/original/3X/c/b/3.pdf",
        short_path: "/uploads/short-url/c.pdf",
      },
    ];
  }

  if (!otherMediaSrcs) {
    otherMediaSrcs = [
      {
        short_url: "upload://d.mp4",
        url: "/uploads/default/original/3X/c/b/4.mp4",
        short_path: "/uploads/short-url/d.mp4",
      },
      {
        short_url: "upload://e.mp3",
        url: "/uploads/default/original/3X/c/b/5.mp3",
        short_path: "/uploads/short-url/e.mp3",
      },
      {
        short_url: "upload://f.mp4",
        url: "http://localhost:3000/uploads/default/original/3X/c/b/6.mp4",
        short_path: "/uploads/short-url/f.mp4",
      },
    ];
  }

  pretender.post("/uploads/lookup-urls", () =>
    response(imageSrcs.concat(attachmentSrcs.concat(otherMediaSrcs)))
  );

  fixture().innerHTML =
    imageSrcs.map((src) => `<img data-orig-src="${src.short_url}"/>`).join("") +
    attachmentSrcs
      .map(
        (src) =>
          `<a data-orig-href="${src.short_url}">big enterprise contract.pdf</a>`
      )
      .join("") +
    `<div class="scoped-area"><img data-orig-src="${imageSrcs[2].url}"></div>` +
    otherMediaSrcs
      .map((src) => {
        if (src.short_url.includes("mp3")) {
          return `<audio controls><source data-orig-src="${src.short_url}"></audio>`;
        } else {
          return `<video controls><source data-orig-src="${src.short_url}"></video>`;
        }
      })
      .join("");
}

module("Unit | Utility | pretty-text/upload-short-url", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    resetCache();
  });

  test("resolveAllShortUrls", async function (assert) {
    stubUrls();
    let lookup;

    lookup = lookupCachedUploadUrl("upload://a.jpeg");
    assert.deepEqual(lookup, {});

    await resolveAllShortUrls(ajax, { secure_uploads: false }, fixture());
    await settled();

    lookup = lookupCachedUploadUrl("upload://a.jpeg");

    assert.deepEqual(lookup, {
      url: "/images/avatar.png?a",
      short_path: "/uploads/short-url/a.jpeg",
    });

    lookup = lookupCachedUploadUrl("upload://b.jpeg");

    assert.deepEqual(lookup, {
      url: "/images/avatar.png?b",
      short_path: "/uploads/short-url/b.jpeg",
    });

    lookup = lookupCachedUploadUrl("upload://c.jpeg");
    assert.deepEqual(lookup, {});

    lookup = lookupCachedUploadUrl("upload://c.pdf");
    assert.deepEqual(lookup, {
      url: "/uploads/default/original/3X/c/b/3.pdf",
      short_path: "/uploads/short-url/c.pdf",
    });

    lookup = lookupCachedUploadUrl("upload://d.mp4");
    assert.deepEqual(lookup, {
      url: "/uploads/default/original/3X/c/b/4.mp4",
      short_path: "/uploads/short-url/d.mp4",
    });

    lookup = lookupCachedUploadUrl("upload://e.mp3");
    assert.deepEqual(lookup, {
      url: "/uploads/default/original/3X/c/b/5.mp3",
      short_path: "/uploads/short-url/e.mp3",
    });

    lookup = lookupCachedUploadUrl("upload://f.mp4");
    assert.deepEqual(lookup, {
      url: "http://localhost:3000/uploads/default/original/3X/c/b/6.mp4",
      short_path: "/uploads/short-url/f.mp4",
    });
  });

  test("resolveAllShortUrls - href + src replaced correctly", async function (assert) {
    stubUrls();
    await resolveAllShortUrls(ajax, { secure_uploads: false }, fixture());
    await settled();

    let image1 = fixture().querySelector("img");
    let image2 = fixture().querySelectorAll("img")[1];
    let audio = fixture().querySelector("audio");
    let video = fixture().querySelector("video");
    let link = fixture().querySelector("a");

    assert.dom(image1).hasAttribute("src", "/images/avatar.png?a");
    assert.dom(image2).hasAttribute("src", "/images/avatar.png?b");
    assert.dom(link).hasAttribute("href", "/uploads/short-url/c.pdf");
    assert
      .dom("source", video)
      .hasAttribute("src", "/uploads/default/original/3X/c/b/4.mp4");
    assert
      .dom("source", audio)
      .hasAttribute("src", "/uploads/default/original/3X/c/b/5.mp3");
  });

  test("resolveAllShortUrls - url with full origin replaced correctly", async function (assert) {
    stubUrls();
    await resolveAllShortUrls(ajax, { secure_uploads: false }, fixture());
    await settled();
    let video = fixture().querySelectorAll("video")[1];

    assert
      .dom("source", video)
      .hasAttribute(
        "src",
        "http://localhost:3000/uploads/default/original/3X/c/b/6.mp4"
      );
  });

  test("resolveAllShortUrls - when secure uploads is enabled use the attachment full URL", async function (assert) {
    stubUrls(
      null,
      [
        {
          short_url: "upload://c.pdf",
          url: "/secure-uploads/default/original/3X/c/b/3.pdf",
          short_path: "/uploads/short-url/c.pdf",
        },
      ],
      null
    );
    await resolveAllShortUrls(ajax, { secure_uploads: true }, fixture());
    await settled();

    let link = fixture().querySelector("a");
    assert
      .dom(link)
      .hasAttribute("href", "/secure-uploads/default/original/3X/c/b/3.pdf");
  });

  test("resolveAllShortUrls - scoped", async function (assert) {
    stubUrls();
    let lookup;

    let scopedElement = fixture().querySelector(".scoped-area");
    await resolveAllShortUrls(ajax, {}, scopedElement);
    await settled();

    lookup = lookupCachedUploadUrl("upload://z.jpeg");

    assert.deepEqual(lookup, {
      url: "/images/avatar.png?z",
      short_path: "/uploads/short-url/z.jpeg",
    });

    // do this because the pretender caches ALL the urls, not
    // just the ones being looked up (like the normal behaviour)
    resetCache();
    await resolveAllShortUrls(ajax, {}, scopedElement);
    await settled();

    lookup = lookupCachedUploadUrl("upload://a.jpeg");
    assert.deepEqual(lookup, {});
  });

  test("cacheShortUploadUrl stores a lookup", function (assert) {
    assert.deepEqual(lookupCachedUploadUrl("upload://a.jpeg"), {});

    cacheShortUploadUrl("upload://a.jpeg", {
      url: "/a.png",
      short_path: "/s/a",
    });

    assert.deepEqual(lookupCachedUploadUrl("upload://a.jpeg"), {
      url: "/a.png",
      short_path: "/s/a",
    });
  });

  test("lookupUncachedUploadUrls skips an empty list", function (assert) {
    let requests = 0;

    const result = lookupUncachedUploadUrls([null, ""], () => requests++);

    assert.strictEqual(result, undefined);
    assert.strictEqual(requests, 0);
  });

  test("lookupUncachedUploadUrls caches what the server finds", async function (assert) {
    const found = {
      short_url: "upload://a.jpeg",
      url: "/a.png",
      short_path: "/s/a",
    };
    pretender.post("/uploads/lookup-urls", () => response([found]));

    const uploads = await lookupUncachedUploadUrls(
      ["upload://a.jpeg", null, "upload://gone.jpeg"],
      ajax
    );

    assert.deepEqual(uploads, [found]);
    assert.deepEqual(lookupCachedUploadUrl("upload://a.jpeg"), {
      url: "/a.png",
      short_path: "/s/a",
    });
    assert.deepEqual(
      lookupCachedUploadUrl("upload://gone.jpeg"),
      { url: MISSING, short_path: MISSING },
      "marks the urls it didn't find as missing"
    );
  });

  test("resolveCachedShortUrls uses only the cache", function (assert) {
    cacheShortUploadUrl("upload://a.jpeg", {
      url: "/a.png",
      short_path: "/s/a",
    });
    fixture().innerHTML =
      '<img data-orig-src="upload://a.jpeg"><img data-orig-src="upload://b.jpeg">';

    resolveCachedShortUrls({}, fixture());

    const [cached, uncached] = fixture().querySelectorAll("img");
    assert.dom(cached).hasAttribute("src", "/a.png");
    assert.dom(cached).doesNotHaveAttribute("data-orig-src");
    assert.dom(uncached).doesNotHaveAttribute("src");
    assert.dom(uncached).hasAttribute("data-orig-src", "upload://b.jpeg");
  });

  test("resolveCachedShortUrls leaves a missing upload alone", function (assert) {
    cacheShortUploadUrl("upload://gone.jpeg", { url: MISSING });
    fixture().innerHTML = '<img data-orig-src="upload://gone.jpeg">';

    resolveCachedShortUrls({}, fixture());

    assert.dom("img", fixture()).doesNotHaveAttribute("src");
    assert.dom("img", fixture()).doesNotHaveAttribute("data-orig-src");
  });

  test("resolveCachedShortUrls replaces a missing upload when asked", function (assert) {
    cacheShortUploadUrl("upload://gone.jpeg", { url: MISSING });
    fixture().innerHTML =
      '<img data-orig-src="upload://gone.jpeg" width="40" height="30">';

    resolveCachedShortUrls({}, fixture(), { removeMissing: true });

    assert.dom("img", fixture()).doesNotExist();
    assert.dom("canvas", fixture()).hasAttribute("width", "40");
    assert.dom("canvas", fixture()).hasAttribute("height", "30");
  });

  test("resolveCachedShortUrls sets a video placeholder's background", function (assert) {
    cacheShortUploadUrl("upload://d.mp4", { url: "/d.png" });
    fixture().innerHTML =
      '<div data-orig-src-id="upload://d.mp4"><span class="placeholder-icon video"></span></div>';

    resolveCachedShortUrls({}, fixture());

    const placeholder = fixture().querySelector("div");
    assert.strictEqual(placeholder.style.backgroundImage, 'url("/d.png")');
    assert.strictEqual(
      placeholder.querySelector(".placeholder-icon").style.backgroundColor,
      "rgba(0, 0, 0, 0.3)"
    );
  });
});
