import { module, test } from "qunit";
import AISentimentDashboard from "discourse/plugins/discourse-ai/discourse/connectors/admin-dashboard-tabs-after/admin-sentiment-dashbboard";

module("Unit | Connector | admin-sentiment-dashboard", function () {
  test("offers reports when either capability is enabled", function (assert) {
    for (const [sentiment, emotion, expected] of [
      [false, false, false],
      [true, false, true],
      [false, true, true],
      [true, true, true],
    ]) {
      assert.strictEqual(
        AISentimentDashboard.shouldRender(
          {},
          {
            siteSettings: {
              ai_sentiment_enabled: sentiment,
              ai_sentiment_emotion_enabled: emotion,
            },
          }
        ),
        expected,
        `reports follow independent flags: sentiment=${sentiment}, emotion=${emotion}`
      );
    }
  });
});
