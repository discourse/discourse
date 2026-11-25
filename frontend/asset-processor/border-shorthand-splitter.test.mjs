/* eslint-disable qunit/require-expect */
import { expect, test } from "vitest";
import {
  splitBorderReads,
  splitBorderSetter,
} from "./border-shorthand-splitter.mjs";

const splits = {
  "--old-border": { width: "--new-width", color: "--new-color" },
  "--old-kind-border": { width: "--new-width", color: "--new-kind-color" },
};

test("rewrites a read to width, style and color", () => {
  expect(splitBorderReads("var(--old-border)", splits)).toEqual({
    value: "var(--new-width) solid var(--new-color)",
    names: ["--old-border"],
  });
});

test("splits a fallback shorthand across both reads", () => {
  expect(
    splitBorderReads("var(--old-kind-border, 2px solid red)", splits).value
  ).toBe("var(--new-width, 2px) solid var(--new-kind-color, red)");
});

test("leaves values without split variables alone", () => {
  expect(splitBorderReads("1px solid var(--other)", splits)).toEqual({
    value: "1px solid var(--other)",
    names: [],
  });
});

test("splits a shorthand setter into width and color", () => {
  expect(
    splitBorderSetter("--old-kind-border", "1px solid var(--accent)", splits)
  ).toEqual({
    declarations: [
      { prop: "--new-width", value: "1px" },
      { prop: "--new-kind-color", value: "var(--accent)" },
    ],
    lost: [],
  });
});

test("points a setter that reads another split variable at its color", () => {
  expect(
    splitBorderSetter("--old-kind-border", "var(--old-border)", splits)
  ).toEqual({
    declarations: [{ prop: "--new-kind-color", value: "var(--new-color)" }],
    lost: [],
  });
});

test("turns a shorthand that draws nothing into a zero width", () => {
  for (const value of ["0", "none", "0 solid red", "1px red"]) {
    expect(splitBorderSetter("--old-border", value, splits)).toEqual({
      declarations: [{ prop: "--new-width", value: "0" }],
      lost: [],
    });
  }
});

test("fills missing parts with the shorthand's initial values", () => {
  expect(
    splitBorderSetter("--old-border", "1px solid", splits).declarations
  ).toEqual([
    { prop: "--new-width", value: "1px" },
    { prop: "--new-color", value: "currentcolor" },
  ]);
});

test("reports a style the split cannot hold", () => {
  expect(splitBorderSetter("--old-border", "3px ridge pink", splits)).toEqual({
    declarations: [
      { prop: "--new-width", value: "3px" },
      { prop: "--new-color", value: "pink" },
    ],
    lost: ["style ridge"],
  });
});

test("cannot split a variable it does not know", () => {
  expect(splitBorderSetter("--old-border", "var(--other)", splits)).toBe(null);
});
