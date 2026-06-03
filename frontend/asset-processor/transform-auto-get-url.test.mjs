import { transformAsync } from "@babel/core";
import { expect, test } from "vitest";
import autoGetUrl from "./transform-auto-get-url.js";

// Compile a template through the real production pipeline (babel +
// ember-template-compilation + our transform) and return both the emitted
// module code and the rewritten template body. `targetFormat: "hbs"` keeps the
// template as a readable string literal in the output, which we extract and
// unescape so we can assert on the exact rewrite.
async function compile(templateBody) {
  const source =
    `import { precompileTemplate } from '@ember/template-compilation';\n` +
    `export default precompileTemplate(${JSON.stringify(
      templateBody
    )}, { strictMode: true });`;

  const { code } = await transformAsync(source, {
    filename: "test.js",
    configFile: false,
    babelrc: false,
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
  });

  const match = code.match(/precompileTemplate\(\s*("(?:[^"\\]|\\.)*")/);
  return { code, template: JSON.parse(match[1]) };
}

test.each([
  ["<a href={{this.url}}>x</a>", "<a href={{getURL this.url}}>x</a>"],
  ['<a href="/about">x</a>', '<a href={{getURL "/about"}}>x</a>'],
  ["<img src={{@logoUrl}}>", "<img src={{getURL @logoUrl}}>"],
  [
    '<a href={{concat "/t/" id}}>x</a>',
    '<a href={{getURL (concat "/t/" id)}}>x</a>',
  ],
  [
    '<a href="/t/{{this.id}}">x</a>',
    '<a href={{getURL (concat "/t/" this.id)}}>x</a>',
  ],
  ["<a href={{if x a b}}>x</a>", "<a href={{getURL (if x a b)}}>x</a>"],
  [
    '<video src={{@v}} poster="/p.png"></video>',
    '<video src={{getURL @v}} poster={{getURL "/p.png"}}></video>',
  ],
])("wraps %s", async (input, expected) => {
  const { template, code } = await compile(input);
  expect(template).toBe(expected);
  expect(code).toContain('import getURL from "discourse/lib/get-url"');
});

test.each([
  ["<a href={{getURL this.url}}>x</a>"],
  ['<a href="https://example.com">x</a>'],
  ['<img src="//cdn/x.png">'],
  ['<a href="#top">x</a>'],
  ['<a href="mailto:a@b.c">x</a>'],
  ['<img src="images/x.png">'],
  ['<base href="/discuss/">'],
  ['<a href="https://x/{{id}}">x</a>'],
  ["<MyLink @href={{this.url}} />"],
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
    "<a data-url={{this.url}} href={{getURL this.url}}>x</a>"
  );
});

test("does not touch srcset", async () => {
  const { template } = await compile(
    '<img src="/a.png" srcset="/a-2x.png 2x">'
  );
  expect(template).toBe('<img src={{getURL "/a.png"}} srcset="/a-2x.png 2x">');
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
