/* eslint-disable qunit/require-expect */
import { expect, test } from "vitest";
import rewriteRgbTwins from "./rgb-twin-rewriter.mjs";

const twins = { "--primary-rgb": "--primary" };

function rewrite(value) {
  return rewriteRgbTwins(value, twins);
}

test("rewrites a numeric alpha to a percentage in color-mix()", () => {
  expect(rewrite("rgba(var(--primary-rgb), 0.07)")).toEqual({
    value: "color-mix(in srgb, var(--primary) 7%, transparent)",
    rewritten: ["--primary-rgb"],
    remaining: [],
  });
});

test("keeps a percentage alpha", () => {
  expect(rewrite("rgb(var(--primary-rgb), 50%)").value).toBe(
    "color-mix(in srgb, var(--primary) 50%, transparent)"
  );
});

test("multiplies a variable alpha into a percentage", () => {
  expect(rewrite("rgb(var(--primary-rgb), var(--alpha))").value).toBe(
    "color-mix(in srgb, var(--primary) calc(var(--alpha) * 100%), transparent)"
  );
});

test("reads the color directly without alpha or with full alpha", () => {
  expect(rewrite("rgb(var(--primary-rgb))").value).toBe("var(--primary)");
  expect(rewrite("rgb(var(--primary-rgb), 1)").value).toBe("var(--primary)");
});

test("rewrites every read in a value", () => {
  expect(
    rewrite(
      "0 0 0 1px rgb(var(--primary-rgb), 0.1), 0 2px 4px rgb(var(--primary-rgb), 0.2)"
    ).value
  ).toBe(
    "0 0 0 1px color-mix(in srgb, var(--primary) 10%, transparent), 0 2px 4px color-mix(in srgb, var(--primary) 20%, transparent)"
  );
});

test("leaves reads it cannot rewrite and reports them", () => {
  for (const value of [
    "rgb(var(--primary-rgb), $amt)",
    "rgb(var(--primary-rgb, 0, 0, 0), 0.5)",
    "rgb(var(--primary-rgb) / 0.5)",
    "var(--primary-rgb)",
  ]) {
    expect(rewrite(value)).toEqual({
      value,
      rewritten: [],
      remaining: ["--primary-rgb"],
    });
  }
});

test("ignores colors that are not twins", () => {
  expect(rewrite("rgb(var(--other-rgb), 0.5)")).toEqual({
    value: "rgb(var(--other-rgb), 0.5)",
    rewritten: [],
    remaining: [],
  });
});
