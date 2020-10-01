import {
  lookupCachedUploadUrl,
  resolveAllShortUrls,
  resetCache,
} from "pretty-text/upload-short-url";
import { ajax } from "discourse/lib/ajax";
import { fixture } from "discourse/tests/helpers/qunit-helpers";
import pretender from "discourse/tests/helpers/create-pretender";

function stubUrls(imageSrcs, attachmentSrcs, otherMediaSrcs) {
  const response = (object) => {
    return [200, { "Content-Type": "application/json" }, object];
  };
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
  // prettier-ignore
  pretender.post("/uploads/lookup-urls", () => { //eslint-disable-line
    return response(imageSrcs.concat(attachmentSrcs.concat(otherMediaSrcs)));
  });

  fixture().html(
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
          if (src.short_url.indexOf("mp3") > -1) {
            return `<audio controls><source data-orig-src="${src.short_url}"></audio>`;
          } else {
            return `<video controls><source data-orig-src="${src.short_url}"></video>`;
          }
        })
        .join("")
  );
}
QUnit.module("lib:pretty-text/upload-short-url", {
  afterEach() {
    resetCache();
  },
});

QUnit.test("resolveAllShortUrls", async (assert) => {
  stubUrls();
  let lookup;

  lookup = lookupCachedUploadUrl("upload://a.jpeg");
  assert.deepEqual(lookup, {});

  await resolveAllShortUrls(ajax, { secure_media: false }, fixture()[0]);

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

QUnit.test(
  "resolveAllShortUrls - href + src replaced correctly",
  async (assert) => {
    stubUrls();
    await resolveAllShortUrls(ajax, { secure_media: false }, fixture()[0]);

    let image1 = fixture().find("img").eq(0);
    let image2 = fixture().find("img").eq(1);
    let link = fixture().find("a");
    let audio = fixture().find("audio").eq(0);
    let video = fixture().find("video").eq(0);

    assert.equal(image1.attr("src"), "/images/avatar.png?a");
    assert.equal(image2.attr("src"), "/images/avatar.png?b");
    assert.equal(link.attr("href"), "/uploads/short-url/c.pdf");
    assert.equal(
      video.find("source").attr("src"),
      "/uploads/default/original/3X/c/b/4.mp4"
    );
    assert.equal(
      audio.find("source").attr("src"),
      "/uploads/default/original/3X/c/b/5.mp3"
    );
  }
);

QUnit.test(
  "resolveAllShortUrls - url with full origin replaced correctly",
  async (assert) => {
    stubUrls();
    await resolveAllShortUrls(ajax, { secure_media: false }, fixture()[0]);
    let video = fixture().find("video").eq(1);

    assert.equal(
      video.find("source").attr("src"),
      "http://localhost:3000/uploads/default/original/3X/c/b/6.mp4"
    );
  }
);

QUnit.test(
  "resolveAllShortUrls - when secure media is enabled use the attachment full URL",
  async (assert) => {
    stubUrls(
      null,
      [
        {
          short_url: "upload://c.pdf",
          url: "/secure-media-uploads/default/original/3X/c/b/3.pdf",
          short_path: "/uploads/short-url/c.pdf",
        },
      ],
      null
    );
    await resolveAllShortUrls(ajax, { secure_media: true }, fixture()[0]);

    let link = fixture().find("a");
    assert.equal(
      link.attr("href"),
      "/secure-media-uploads/default/original/3X/c/b/3.pdf"
    );
  }
);

QUnit.test("resolveAllShortUrls - scoped", async (assert) => {
  stubUrls();
  let lookup;

  let scopedElement = fixture()[0].querySelector(".scoped-area");
  await resolveAllShortUrls(ajax, {}, scopedElement);

  lookup = lookupCachedUploadUrl("upload://z.jpeg");

  assert.deepEqual(lookup, {
    url: "/images/avatar.png?z",
    short_path: "/uploads/short-url/z.jpeg",
  });

  // do this because the pretender caches ALL the urls, not
  // just the ones being looked up (like the normal behaviour)
  resetCache();
  await resolveAllShortUrls(ajax, {}, scopedElement);

  lookup = lookupCachedUploadUrl("upload://a.jpeg");
  assert.deepEqual(lookup, {});
});
