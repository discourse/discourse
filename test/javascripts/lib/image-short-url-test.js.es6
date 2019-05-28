import {
  lookupCachedUploadUrl,
  resolveAllShortUrls,
  resetCache
} from "pretty-text/image-short-url";
import { ajax } from "discourse/lib/ajax";

QUnit.module("lib:pretty-text/image-short-url", {
  beforeEach() {
    const response = object => {
      return [200, { "Content-Type": "application/json" }, object];
    };

    const srcs = [
      {
        short_url: "upload://a.jpeg",
        url: "/uploads/default/original/3X/c/b/1.jpeg"
      },
      {
        short_url: "upload://b.jpeg",
        url: "/uploads/default/original/3X/c/b/2.jpeg"
      }
    ];

    // prettier-ignore
    server.post("/uploads/lookup-urls", () => { //eslint-disable-line
      return response(srcs);
    });

    fixture().html(
      srcs.map(src => `<img data-orig-src="${src.url}">`).join("")
    );
  },

  afterEach() {
    resetCache();
  }
});

QUnit.test("resolveAllShortUrls", async assert => {
  let lookup;

  lookup = lookupCachedUploadUrl("upload://a.jpeg");
  assert.notOk(lookup);

  await resolveAllShortUrls(ajax);

  lookup = lookupCachedUploadUrl("upload://a.jpeg");
  assert.equal(lookup, "/uploads/default/original/3X/c/b/1.jpeg");

  lookup = lookupCachedUploadUrl("upload://b.jpeg");
  assert.equal(lookup, "/uploads/default/original/3X/c/b/2.jpeg");

  lookup = lookupCachedUploadUrl("upload://c.jpeg");
  assert.notOk(lookup);
});
