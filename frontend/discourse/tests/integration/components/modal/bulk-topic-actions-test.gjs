import { getOwner } from "@ember/owner";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import BulkTopicActions from "discourse/components/modal/bulk-topic-actions";
import ModalContainer from "discourse/components/modal-container";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, {
  middlewareRateLimit,
  response,
} from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";

const CHUNK_SIZE = 30;
const TOPIC_COUNT = 2 * CHUNK_SIZE + 1;

function withoutMarkup(key, count) {
  return i18n(key, { count }).replace(/<\/?b>/g, "");
}

module(
  "Integration | Component | Modal | bulk-topic-actions",
  function (hooks) {
    setupRenderingTest(hooks);

    test("reports what a partially applied bulk action did and did not change", async function (assert) {
      const selected = Array.from({ length: TOPIC_COUNT }, (_, i) => ({
        id: i + 1,
      }));

      let requestCount = 0;
      pretender.put("/topics/bulk", () => {
        requestCount++;
        if (requestCount === 1) {
          return response({
            topic_ids: selected.slice(0, CHUNK_SIZE).map((topic) => topic.id),
          });
        }
        return middlewareRateLimit(60);
      });

      await render(<template><ModalContainer /></template>);

      getOwner(this)
        .lookup("service:modal")
        .show(BulkTopicActions, {
          model: {
            action: "reset-bump-dates",
            title: "Reset bump dates",
            showFooter: true,
            bulkSelectHelper: { selected, toggleBulkSelect: () => {} },
          },
        });
      await settled();

      await click("#bulk-topics-confirm");

      assert.strictEqual(
        requestCount,
        2,
        "it stops sending chunks after the first failure"
      );
      assert
        .dom(".topic-bulk-actions-modal__errors")
        .includesText(
          withoutMarkup("topics.bulk.completed_count", CHUNK_SIZE),
          "the applied topics are reported"
        );
      assert
        .dom(".topic-bulk-actions-modal__errors")
        .includesText(
          withoutMarkup("topics.bulk.not_completed", CHUNK_SIZE),
          "the failed topics are reported"
        );
      assert
        .dom(".topic-bulk-actions-modal__errors")
        .includesText(
          withoutMarkup(
            "topics.bulk.skipped_count",
            TOPIC_COUNT - 2 * CHUNK_SIZE
          ),
          "the topics that were never tried are reported"
        );
    });
  }
);
