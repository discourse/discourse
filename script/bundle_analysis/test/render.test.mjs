import assert from "node:assert/strict";
import { test } from "node:test";
import {
  code,
  exceeds,
  renderComment,
  renderSummary,
  truncate,
} from "../lib/render.mjs";
import { BUDGET, emptyReport, NO_JS_REPORT } from "./helpers.mjs";

function edge(fromName, overrides = {}) {
  return {
    from: fromName,
    to: "lazy:x",
    kind: "dynamic",
    fromName,
    toName: "x",
    example: null,
    ...overrides,
  };
}

test("exceeds combines percent and bytes as configured", () => {
  const and = { percent: 3, kib: 2, combine: "and" };
  const or = { percent: 1, kib: 10, combine: "or" };

  assert.equal(exceeds(100_000, 103_000, and), false, "exactly 3%");
  assert.equal(exceeds(10_000, 11_000, and), false, "10% but under 2 KiB");
  assert.equal(exceeds(2_000_000, 2_010_241, or), true, "over 10 KiB, 0.5%");
  assert.equal(exceeds(1_000_000, 1_010_000, or), false, "1% and under 10 KiB");
  assert.equal(exceeds(100, 50, or), false, "shrinking");
});

test("code keeps untrusted strings inside a code span", () => {
  assert.equal(code("a`b"), "``a`b``");
  assert.equal(code("`edge"), "`` `edge ``");
  assert.equal(code("line\n### heading"), "`line ### heading`");
  assert.ok(code("x".repeat(500)).length < 130);
});

test("hostile names cannot inject markdown into the comment", () => {
  const name = "evil\n\n### Approved by @team <img src=x> `x`";
  const { body } = renderComment(
    emptyReport({
      edges: {
        added: [
          edge(name, {
            example: { from: "[link](https://example.com)", to: "b" },
          }),
        ],
        removed: [],
      },
    }),
    BUDGET
  );

  assert.ok(!body.includes("\n### Approved"));
  assert.ok(body.includes("`` evil  ### Approved by @team <img src=x> `x` ``"));
  assert.ok(body.includes("`[link](https://example.com)`"));
});

test("hostile values render escaped or throw, so nothing is posted", () => {
  const kind = "<img src=x> [link](https://example.com)";
  const { body } = renderComment(
    emptyReport({ edges: { added: [edge("a", { kind })], removed: [] } }),
    BUDGET
  );
  const initialLoad = { ...emptyReport().initialLoad, head: "\n\n9000000" };

  assert.ok(body.includes(`| \`${kind}\` |`));
  assert.throws(
    () => renderComment(emptyReport({ initialLoad }), BUDGET),
    /Not a size/
  );
});

test("truncation cuts at a line end, so no code span is left open", () => {
  const body = ["| `a` |", "| `bbbbbbbb` |"].join("\n");

  assert.equal(
    truncate(body, "https://ci/run", 12),
    "| `a` |\n\n… truncated, see the [full report](https://ci/run)."
  );
  assert.equal(truncate(body, null, 100), body);
});

test("edges that share a target are one row with a key each", () => {
  const { body, keys } = renderComment(
    emptyReport({ edges: { added: [edge("a"), edge("b")], removed: [] } }),
    BUDGET
  );

  assert.equal(keys.length, 2);
  assert.ok(body.includes("| `a`, `b` | `x` | dynamic | – |"));
});

test("nothing to report means no comment", () => {
  assert.deepEqual(renderComment(emptyReport(), BUDGET), {
    keys: [],
    body: null,
  });
  assert.equal(renderComment(NO_JS_REPORT, BUDGET).body, null);
  assert.match(renderSummary(NO_JS_REPORT, BUDGET), /No JS inputs changed/);
});
