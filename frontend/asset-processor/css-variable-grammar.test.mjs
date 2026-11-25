/* eslint-disable qunit/require-expect */
import { expect, test } from "vitest";
import vocabulary from "../../app/assets/stylesheets/variable-vocabulary.json";
import createGrammar from "./css-variable-grammar.mjs";

const parse = createGrammar(vocabulary);

test("accepts names that follow the scheme", () => {
  for (const name of [
    "--d-sys-color-text-default",
    "--d-sys-color-text-default-disabled",
    "--d-sys-color-background-default-hovered",
    "--d-sys-color-background-highlight-bold",
    "--d-sys-border-radius-md",
    "--d-sys-font-weight-bold",
    "--d-sys-shadow-overflow",
    "--d-comp-DButton-color-background-primary-hovered",
    "--d-comp-DButton-border-width",
    "--d-comp-DButton-motion-transition",
    "--d-comp-PostMenu-button-border-radius",
    "--d-comp-Header-space-padding-inline",
    "--d-comp-UserBadge-color-icon-gold",
  ]) {
    expect(parse(name).errors, name).toEqual([]);
  }
});

test("rejects names outside the layers", () => {
  expect(parse("--primary-medium").errors).toEqual([
    "Unknown prefix. Use --d-sys-, --d-comp-, --t-, --tc- or --p-.",
  ]);
  expect(parse("--d-button-border").errors).toEqual([
    "Under --d- only sys and comp are allowed.",
  ]);
});

test("rejects words that break the slot rules", () => {
  expect(parse("--d-sys-color-text").errors[0]).toMatch(/role is required/);
  expect(parse("--d-sys-color-text-default-active").errors[0]).toMatch(
    /"active" is not allowed/
  );
  expect(parse("--d-sys-color-text-default-hover").errors[0]).toMatch(
    /past participle/
  );
  expect(parse("--d-comp-button-color-text").errors[0]).toMatch(/PascalCase/);
  expect(parse("--d-sys-colour-text-default").errors[0]).toMatch(
    /not a category/
  );
});

test("notes a part the vocabulary does not list yet", () => {
  const result = parse("--d-comp-Header-logo-size-icon");
  expect(result.errors).toEqual([]);
  expect(result.notes[0]).toMatch(/"logo" is a new part of Header/);
});
