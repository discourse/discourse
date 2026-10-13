import { module, test } from "qunit";
import sanitizeError from "discourse/plugins/voice/discourse/lib/voice/sanitize-error";

module("Voice | Unit | Lib | sanitize-error", function () {
  test("retains diagnostic fields without stacks or nested payloads", function (assert) {
    const error = new Error("track publication timed out");
    error.name = "PublishError";
    error.code = 401;
    error.cause = { token: "private-token" };
    error.track = { label: "private-device" };

    assert.deepEqual(
      sanitizeError(error),
      {
        name: "PublishError",
        code: 401,
        message: "track publication timed out",
      },
      "only diagnostic fields are retained"
    );
  });

  test("redacts sensitive message content", function (assert) {
    const messages = [
      "connect failed: wss://user:password@private.example/rtc?access_token=secret",
      "connect failed: Bearer secret-token",
      'connect failed: token="secret token"',
      "connect failed: api_key=private-key",
      "connect failed: eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.signature",
      "connect failed: 192.168.1.2",
      "connect failed: 2001:db8::1",
      "connect failed: person@example.com",
      "connect failed: sdp=v=0 private SDP",
      "connect failed: transcript=private words",
    ];
    for (const message of messages) {
      assert.strictEqual(
        sanitizeError(new Error(message)).message,
        "connect failed: [FILTERED]",
        "sensitive content is redacted"
      );
    }
  });

  test("drops embedded payloads and limits message length", function (assert) {
    for (const message of [
      'publish failed {"token":"secret"}',
      'publish failed ["private words"]',
      "publish failed\nprivate SDP",
    ]) {
      assert.strictEqual(
        sanitizeError(new Error(message)).message,
        "publish failed [FILTERED]",
        "payload is omitted"
      );
    }
    assert.strictEqual(
      sanitizeError(new Error("x".repeat(300))).message.length,
      200,
      "message length is bounded"
    );
  });

  test("handles missing and non-error values without serializing them", function (assert) {
    assert.strictEqual(
      sanitizeError(null),
      undefined,
      "missing error is omitted"
    );
    assert.strictEqual(
      sanitizeError({ response: { token: "secret" } }),
      undefined,
      "response objects are omitted"
    );
    assert.deepEqual(
      sanitizeError("publish failed"),
      { message: "publish failed" },
      "string errors retain a sanitized message"
    );
  });
});
