import { module, test } from "qunit";
import { normalizeAiUsageTimeSeriesData } from "discourse/plugins/discourse-ai/discourse/lib/ai-usage-time-series";

module("Unit | Lib | ai-usage-time-series", function () {
  test("normalizes around server data without clamping", function (assert) {
    const rows = [
      {
        period: "2026-06-15T10:00:00Z",
        total_tokens: 100,
        total_cache_read_tokens: 0,
        total_cache_write_tokens: 0,
        total_request_tokens: 75,
        total_response_tokens: 25,
      },
      {
        period: "2026-06-15T13:00:00Z",
        total_tokens: 200,
        total_cache_read_tokens: 0,
        total_cache_write_tokens: 0,
        total_request_tokens: 150,
        total_response_tokens: 50,
      },
    ];

    const normalized = normalizeAiUsageTimeSeriesData(rows, "hour", {
      start: "2026-06-15T12:00:00Z",
      end: "2026-06-15T14:00:00Z",
    });

    assert.strictEqual(
      moment(normalized[0].period).format("HH:00"),
      "10:00",
      "starts at the earliest server row, even when it is before the selected range"
    );
    assert.strictEqual(
      normalized[0].total_tokens,
      100,
      "keeps the server row that would otherwise be clamped"
    );
    assert.strictEqual(
      moment(normalized[normalized.length - 1].period).format("HH:00"),
      "14:00",
      "extends through the server-provided date range"
    );
  });

  test("extends a single server data point over the date range", function (assert) {
    const normalized = normalizeAiUsageTimeSeriesData(
      [
        {
          period: "2026-06-15T13:00:00Z",
          total_tokens: 200,
          total_cache_read_tokens: 0,
          total_cache_write_tokens: 0,
          total_request_tokens: 150,
          total_response_tokens: 50,
        },
      ],
      "hour",
      {
        start: "2026-06-15T12:00:00Z",
        end: "2026-06-15T14:00:00Z",
      }
    );

    assert.deepEqual(
      normalized.map((row) => moment(row.period).format("HH:00")),
      ["12:00", "13:00", "14:00"],
      "uses the server date range to avoid a one-point chart"
    );
    assert.deepEqual(
      normalized.map((row) => row.total_tokens),
      [0, 200, 0],
      "fills missing periods without dropping the server data point"
    );
  });

  test("pads a one-bucket server range", function (assert) {
    const normalized = normalizeAiUsageTimeSeriesData(
      [
        {
          period: "2026-06-15T13:00:00Z",
          total_tokens: 200,
          total_cache_read_tokens: 0,
          total_cache_write_tokens: 0,
          total_request_tokens: 150,
          total_response_tokens: 50,
        },
      ],
      "hour",
      {
        start: "2026-06-15T13:00:00Z",
        end: "2026-06-15T13:00:00Z",
      }
    );

    assert.deepEqual(
      normalized.map((row) => moment(row.period).format("HH:00")),
      ["12:00", "13:00", "14:00"],
      "extends around a single returned bucket"
    );
    assert.deepEqual(
      normalized.map((row) => row.total_tokens),
      [0, 200, 0],
      "keeps the returned bucket visible"
    );
  });
});
