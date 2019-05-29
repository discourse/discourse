import {
  lookupCachedUploadUrl,
  resolveAllShortUrls,
  resetCache
} from "pretty-text/upload-short-url";
import { ajax } from "discourse/lib/ajax";

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

    // prettier-ignore
    server.post("/uploads/lookup-urls", () => { //eslint-disable-line
      return response(imageSrcs.concat(attachmentSrcs));
    });

    fixture().html(
      imageSrcs.map(src => `<img data-orig-src="${src.url}">`).join("") +
        attachmentSrcs.map(src => `<a data-orig-href="${src.url}">`).join("")
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
});
