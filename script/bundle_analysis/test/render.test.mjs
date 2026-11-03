import assert from "node:assert/strict";
import { test } from "node:test";
import {
  code,
  exceeds,
  kib,
  renderComment,
  renderSummary,
} from "../lib/render.mjs";
import { BUDGET } from "./helpers.mjs";

test("exceeds combines percent and bytes as configured", () => {
  const and = { percent: 3, kib: 2, combine: "and" };
  const or = { percent: 1, kib: 10, combine: "or" };

  assert.equal(exceeds(100_000, 103_000, and), false, "exactly 3%");
  assert.equal(exceeds(100_000, 103_001, and), true);
  assert.equal(exceeds(10_000, 11_000, and), false, "10% but under 2 KiB");
  assert.equal(exceeds(1_000_000, 1_010_241, or), true, "over 10 KiB, 1.02%");
  assert.equal(exceeds(1_000_000, 1_010_000, or), false, "1% and under 10 KiB");
  assert.equal(exceeds(2_000_000, 2_010_241, or), true, "over 10 KiB, 0.5%");
  assert.equal(exceeds(100, 50, or), false, "shrinking");
  assert.equal(exceeds(0, 5000, and), true, "from nothing");
});

test("kib formats bytes, KiB with a decimal, and large values", () => {
  assert.equal(kib(512), "512 B");
  assert.equal(kib(2048), "2.0 KiB");
  assert.equal(kib(1_139_712), "1,113 KiB");
  assert.equal(kib(-3072), "-3.0 KiB");
});

test("code keeps untrusted strings inside a code span", () => {
  assert.equal(code("app/lib/a.js"), "`app/lib/a.js`");
  assert.equal(code("a`b"), "``a`b``");
  assert.equal(code("`edge"), "`` `edge ``");
  assert.equal(code("line\n### heading"), "`line ### heading`");
  assert.ok(code("x".repeat(500)).length < 130);
});

function report(overrides = {}) {
  return {
    schema: 2,
    noJsChanges: false,
    initialLoad: {
      base: 1_000_000,
      head: 1_000_000,
      entryOwn: { base: 600_000, head: 600_000 },
      chunks: { base: 20, head: 20 },
      topModules: [],
    },
    totals: {
      base: 3_000_000,
      head: 3_000_000,
      chunks: { base: 50, head: 50 },
    },
    bundles: [],
    movedIntoInitialLoad: [],
    edges: { added: [], removed: [] },
    assets: [],
    duplicatePackages: [],
    ...overrides,
  };
}

test("tiny changes show as under 0.1%", () => {
  const { body } = renderComment(
    report({
      initialLoad: { ...report().initialLoad, head: 999_609 },
      edges: {
        added: [
          {
            from: "a",
            to: "b",
            kind: "dynamic",
            fromName: "a",
            toName: "b",
            examples: [],
          },
        ],
        removed: [],
      },
    }),
    BUDGET
  );

  assert.ok(body.includes("(-391 B, -<0.1%)"));
});

test("no findings means no comment", () => {
  assert.deepEqual(renderComment(report(), BUDGET), { keys: [], body: null });
  assert.equal(
    renderComment({ schema: 2, noJsChanges: true }, BUDGET).body,
    null
  );
});

test("hostile names cannot inject markdown into the comment", () => {
  const name = "evil\n\n### Approved by @team <img src=x> `x`";
  const { body } = renderComment(
    report({
      edges: {
        added: [
          {
            from: "a",
            to: "b",
            kind: "dynamic",
            fromName: name,
            toName: "b",
            examples: [{ from: "[link](https://example.com)", to: "b" }],
          },
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

test("edges that share a target are grouped", () => {
  const edge = (from) => ({
    from,
    to: "lazy:x",
    kind: "dynamic",
    fromName: from,
    toName: "x",
    examples: [],
  });
  const { body, keys } = renderComment(
    report({ edges: { added: [edge("a"), edge("b")], removed: [] } }),
    BUDGET
  );

  assert.equal(keys.length, 2);
  assert.ok(body.includes("| `a`, `b` | `x` | dynamic | – |"));
});

test("the summary renders a no-changes report", () => {
  assert.match(
    renderSummary({ schema: 2, noJsChanges: true }, BUDGET),
    /No JS inputs changed/
  );
});
