import { transformAsync } from "@babel/core";
import { expect, test } from "vitest";
import autoGetUrl from "./transform-auto-get-url.js";

const BABEL_OPTIONS = {
  configFile: false,
  plugins: [
    [
      "babel-plugin-ember-template-compilation",
      {
        compilerPath: "ember-source/ember-template-compiler/index.js",
        targetFormat: "hbs",
        transforms: [autoGetUrl],
      },
    ],
  ],
};

// `targetFormat: "hbs"` keeps the compiled template as a readable string
// literal, which we extract and unescape to assert on the exact rewrite.
async function compile(templateBody) {
  const source = `import { precompileTemplate } from '@ember/template-compilation';
export default precompileTemplate(${JSON.stringify(templateBody)}, { strictMode: true });`;

  const { code } = await transformAsync(source, BABEL_OPTIONS);
  const template = JSON.parse(
    code.match(/precompileTemplate\(\s*("(?:[^"\\]|\\.)*")/)[1]
  );
  return { code, template };
}

test.each([
  [
    "<a href={{this.url}}>x</a>",
    "<a href={{getURLForAttribute this.url}}>x</a>",
  ],
  ['<a href="/about">x</a>', '<a href={{getURLForAttribute "/about"}}>x</a>'],
  [
    '<a href={{concat "/t/" id}}>x</a>',
    '<a href={{getURLForAttribute (concat "/t/" id)}}>x</a>',
  ],
  [
    '<a href="/t/{{this.id}}">x</a>',
    '<a href={{getURLForAttribute (concat "/t/" this.id)}}>x</a>',
  ],
  [
    "<a href={{if x a b}}>x</a>",
    "<a href={{getURLForAttribute (if x a b)}}>x</a>",
  ],
])("wraps %s", async (input, expected) => {
  const { template, code } = await compile(input);
  expect(template).toBe(expected);
  expect(code).toContain(
    'import { getURLForAttribute } from "discourse/lib/get-url"'
  );
});

test.each([
  ["<a href={{getURL this.url}}>x</a>"],
  ['<a href="https://example.com">x</a>'],
  ['<a href="#top">x</a>'],
  ['<a href="mailto:a@b.c">x</a>'],
  ['<base href="/discuss/">'],
  ['<a href="https://x/{{id}}">x</a>'],
  ["<MyLink @href={{this.url}} />"],
  ["<img src={{@logoUrl}}>"],
  ['<img src="/a.png" srcset="/a-2x.png 2x">'],
  ['<video src={{@v}} poster="/p.png"></video>'],
  ['<form action="/post">x</form>'],
])("leaves %s untouched", async (input) => {
  const { template, code } = await compile(input);
  expect(template).toBe(input);
  expect(code).not.toContain("discourse/lib/get-url");
});

test("only wraps the url attribute, not siblings", async () => {
  const { template } = await compile(
    "<a data-url={{this.url}} href={{this.url}}>x</a>"
  );
  expect(template).toBe(
    "<a data-url={{this.url}} href={{getURLForAttribute this.url}}>x</a>"
  );
});

test("imports concat when synthesizing one for a literal+binding href", async () => {
  const { code } = await compile('<a href="/t/{{this.id}}">x</a>');
  expect(code).toContain('import { concat } from "@ember/helper"');
});

test("emits a strict-mode scope binding for the injected helper", async () => {
  const { code } = await compile("<a href={{this.url}}>x</a>");
  expect(code).toContain("scope: () => ({");
  expect(code).toContain("getURL");
});

test("no-ops without jsutils (defensive)", () => {
  const result = autoGetUrl({ syntax: { builders: {} } });
  expect(Object.keys(result.visitor)).toHaveLength(0);
});
