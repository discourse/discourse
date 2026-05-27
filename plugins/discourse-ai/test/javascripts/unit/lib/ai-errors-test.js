import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  isAiCreditLimitError,
  popupAiCreditLimitError,
} from "discourse/plugins/discourse-ai/discourse/lib/ai-errors";

module("Unit | Utility | ai-errors", function (hooks) {
  setupTest(hooks);

  module("isAiCreditLimitError", function () {
    test("detects AJAX error format from controller", function (assert) {
      const error = {
        jqXHR: {
          responseJSON: {
            error: "credit_limit_exceeded",
          },
        },
      };

      assert.true(
        isAiCreditLimitError(error),
        "Should detect controller error format"
      );
    });

    test("detects MessageBus payload format from streaming job", function (assert) {
      const payload = {
        error_type: "credit_limit_exceeded",
        message: "Credit limit exceeded",
        details: {},
      };

      assert.true(
        isAiCreditLimitError(payload),
        "Should detect streaming job format"
      );
    });

    test("detects direct error object format", function (assert) {
      const error = {
        error: "credit_limit_exceeded",
      };

      assert.true(
        isAiCreditLimitError(error),
        "Should detect direct error format"
      );
    });

    test("returns false for non-credit-limit errors", function (assert) {
      const error = {
        jqXHR: {
          responseJSON: {
            error: "some_other_error",
          },
        },
      };

      assert.false(
        isAiCreditLimitError(error),
        "Should not detect other errors"
      );
    });

    test("returns false for unrelated objects", function (assert) {
      assert.false(
        isAiCreditLimitError({}),
        "Should return false for empty object"
      );
      assert.false(isAiCreditLimitError(null), "Should return false for null");
      assert.false(
        isAiCreditLimitError(undefined),
        "Should return false for undefined"
      );
    });
  });

  module("popupAiCreditLimitError", function () {
    test("shows dialog with reset time when available", function (assert) {
      const dialogService = getOwner(this).lookup("service:dialog");
      const alertStub = sinon.stub(dialogService, "alert");

      const error = {
        jqXHR: {
          responseJSON: {
            error: "credit_limit_exceeded",
            details: {
              reset_time_absolute: "5:40pm on Dec 25, 2024",
            },
          },
        },
      };

      popupAiCreditLimitError(error);

      assert.true(alertStub.calledOnce, "Dialog should be shown");
      const callArgs = alertStub.firstCall.args[0];
      // Convert htmlSafe string to regular string for testing
      const messageStr = callArgs.message.toString();
      assert.true(
        messageStr.includes("5:40pm on Dec 25, 2024"),
        "Message should include reset time"
      );
      assert.strictEqual(
        callArgs.title,
        "AI credit limit reached",
        "Title should be correct"
      );

      alertStub.restore();
    });

    test("shows dialog without reset time when unavailable", function (assert) {
      const dialogService = getOwner(this).lookup("service:dialog");
      const alertStub = sinon.stub(dialogService, "alert");

      const error = {
        error_type: "credit_limit_exceeded",
        details: {},
      };

      popupAiCreditLimitError(error);

      assert.true(alertStub.calledOnce, "Dialog should be shown");
      const callArgs = alertStub.firstCall.args[0];
      // Convert htmlSafe string to regular string for testing
      const messageStr = callArgs.message.toString();
      assert.false(
        /\bat\b\s+\d/.test(messageStr),
        "Message should not include time formatted as 'at [time]'"
      );
      assert.true(
        messageStr.includes("until your limit resets"),
        "Message should mention reset"
      );

      alertStub.restore();
    });

    test("handles MessageBus payload format", function (assert) {
      const dialogService = getOwner(this).lookup("service:dialog");
      const alertStub = sinon.stub(dialogService, "alert");

      const payload = {
        error_type: "credit_limit_exceeded",
        details: {
          reset_time_relative: "2h",
        },
      };

      popupAiCreditLimitError(payload);

      assert.true(alertStub.calledOnce, "Dialog should be shown");
      const callArgs = alertStub.firstCall.args[0];
      // Convert htmlSafe string to regular string for testing
      const messageStr = callArgs.message.toString();
      assert.true(
        messageStr.includes("2h"),
        "Message should include relative time"
      );

      alertStub.restore();
    });
  });
});
