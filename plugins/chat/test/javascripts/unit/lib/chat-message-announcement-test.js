import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { messageAnnouncementText } from "discourse/plugins/chat/discourse/lib/chat-message-announcement";

function message(overrides = {}) {
  return {
    user: { username: "alice" },
    message: "",
    excerpt: "",
    uploads: [],
    ...overrides,
  };
}

module("Unit | Lib | chat-message-announcement", function (hooks) {
  setupTest(hooks);

  test("text message reads sender and text", function (assert) {
    assert.strictEqual(
      messageAnnouncementText(message({ message: "hello", excerpt: "hello" })),
      "alice: hello"
    );
  });

  test("decodes HTML entities from the excerpt", function (assert) {
    assert.strictEqual(
      messageAnnouncementText(
        message({ message: "you & me", excerpt: "you &amp; me" })
      ),
      "alice: you & me"
    );
  });

  test("image-only message is announced as an image", function (assert) {
    assert.strictEqual(
      messageAnnouncementText(
        message({
          excerpt: "photo.png",
          uploads: [{ original_filename: "photo.png" }],
        })
      ),
      "alice sent an image"
    );
  });

  test("multiple images are counted", function (assert) {
    assert.strictEqual(
      messageAnnouncementText(
        message({
          uploads: [
            { original_filename: "a.png" },
            { original_filename: "b.jpg" },
          ],
        })
      ),
      "alice sent 2 images"
    );
  });

  test("a non-image upload is announced as an attachment", function (assert) {
    assert.strictEqual(
      messageAnnouncementText(
        message({ uploads: [{ original_filename: "report.pdf" }] })
      ),
      "alice sent an attachment"
    );
  });

  test("a caption is read together with its image", function (assert) {
    assert.strictEqual(
      messageAnnouncementText(
        message({
          message: "look at this",
          excerpt: "look at this",
          uploads: [{ original_filename: "photo.png" }],
        })
      ),
      "alice: look at this (with an image)"
    );
  });
});
