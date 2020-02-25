import {
  lookupCachedUploadUrl,
  resolveAllShortUrls,
  resetCache
} from "pretty-text/upload-short-url";
import { ajax } from "discourse/lib/ajax";
import { fixture } from "helpers/qunit-helpers";

QUnit.module("lib:pretty-text/upload-short-url", {
  beforeEach() {
    const response = object => {
      return [200, { "Content-Type": "application/json" }, object];
    };

    const imageSrcs = [
      {
        short_url: "upload://a.jpeg",
        url: "/uploads/default/original/3X/c/b/1.jpeg",
        short_path: "/uploads/short-url/a.jpeg"
      },
      {
        short_url: "upload://b.jpeg",
        url: "/uploads/default/original/3X/c/b/2.jpeg",
        short_path: "/uploads/short-url/b.jpeg"
      }
    ];

    const attachmentSrcs = [
      {
        short_url: "upload://c.pdf",
        url: "/uploads/default/original/3X/c/b/3.pdf",
        short_path: "/uploads/short-url/c.pdf"
      }
    ];

    const otherMediaSrcs = [
      {
        short_url: "upload://d.mp4",
        url: "/uploads/default/original/3X/c/b/4.mp4",
        short_path: "/uploads/short-url/d.mp4"
      },
      {
        short_url: "upload://e.mp3",
        url: "/uploads/default/original/3X/c/b/5.mp3",
        short_path: "/uploads/short-url/e.mp3"
      }
    ];

    // prettier-ignore
    server.post("/uploads/lookup-urls", () => { //eslint-disable-line
      return response(imageSrcs.concat(attachmentSrcs.concat(otherMediaSrcs)));
    });

    fixture().html(
      imageSrcs.map(src => `<img data-orig-src="${src.short_url}"/>`).join("") +
        attachmentSrcs
          .map(
            src =>
              `<a data-orig-href="${src.short_url}">big enterprise contract.pdf</a>`
          )
          .join("")
    );
  },

  afterEach() {
    resetCache();
  }
});

QUnit.test("resolveAllShortUrls", async assert => {
  let lookup;

  lookup = lookupCachedUploadUrl("upload://a.jpeg");
  assert.deepEqual(lookup, {});

  await resolveAllShortUrls(ajax);

  lookup = lookupCachedUploadUrl("upload://a.jpeg");

  assert.deepEqual(lookup, {
    url: "/uploads/default/original/3X/c/b/1.jpeg",
    short_path: "/uploads/short-url/a.jpeg"
  });

  lookup = lookupCachedUploadUrl("upload://b.jpeg");

  assert.deepEqual(lookup, {
    url: "/uploads/default/original/3X/c/b/2.jpeg",
    short_path: "/uploads/short-url/b.jpeg"
  });

  lookup = lookupCachedUploadUrl("upload://c.jpeg");
  assert.deepEqual(lookup, {});

  lookup = lookupCachedUploadUrl("upload://c.pdf");
  assert.deepEqual(lookup, {
    url: "/uploads/default/original/3X/c/b/3.pdf",
    short_path: "/uploads/short-url/c.pdf"
  });

  lookup = lookupCachedUploadUrl("upload://d.mp4");
  assert.deepEqual(lookup, {
    url: "/uploads/default/original/3X/c/b/4.mp4",
    short_path: "/uploads/short-url/d.mp4"
  });

  lookup = lookupCachedUploadUrl("upload://e.mp3");
  assert.deepEqual(lookup, {
    url: "/uploads/default/original/3X/c/b/5.mp3",
    short_path: "/uploads/short-url/e.mp3"
  });
});

QUnit.test(
  "resolveAllShortUrls - href + src replaced correctly",
  async assert => {
    await resolveAllShortUrls(ajax);

    let image1 = fixture()
      .find("img")
      .eq(0);
    let image2 = fixture()
      .find("img")
      .eq(1);
    let link = fixture().find("a");

    assert.equal(image1.attr("src"), "/uploads/default/original/3X/c/b/1.jpeg");
    assert.equal(image2.attr("src"), "/uploads/default/original/3X/c/b/2.jpeg");
    assert.equal(link.attr("href"), "/uploads/short-url/c.pdf");
  }
);

QUnit.test(
  "resolveAllShortUrls - when secure media is enabled use the attachment full URL",
  async assert => {
    Discourse.SiteSettings.secure_media = true;
    await resolveAllShortUrls(ajax);

    let link = fixture().find("a");
    assert.equal(link.attr("href"), "/uploads/default/original/3X/c/b/3.pdf");
  }
);
