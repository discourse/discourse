import { Linter } from "eslint";
import assert from "node:assert/strict";
import { test } from "node:test";
import rule from "./no-cross-group-internals.mjs";

const APP = "frontend/discourse/app";

/**
 * Oracle for the -internals import guard (unit U4). Files are virtual — the
 * rule must reason about the import specifier and the importing filename
 * alone, with no filesystem access, so the fixtures never touch the tree.
 * Filenames stay repo-relative because flat-config matching is based on the
 * process cwd; an absolute path outside it matches no configuration at all.
 */
function lint(filename, code) {
  const linter = new Linter();
  return linter.verify(
    code,
    {
      plugins: {
        discourse: { rules: { "no-cross-group-internals": rule } },
      },
      languageOptions: { ecmaVersion: "latest", sourceType: "module" },
      rules: { "discourse/no-cross-group-internals": "error" },
    },
    { filename }
  );
}

function messagesFor(filename, code) {
  return lint(filename, code).map((m) => m.ruleId);
}

test("an app file outside the group cannot import its internals", () => {
  const messages = messagesFor(
    `${APP}/components/composer.js`,
    `import PanelDockChassis from "discourse/ui-kit/panel-dock/-internals/panel";`
  );
  assert.deepEqual(messages, ["discourse/no-cross-group-internals"]);
});

test("a relative reach-in from outside the group is refused", () => {
  const messages = messagesFor(
    `${APP}/components/composer.js`,
    `import PanelDockChassis from "../ui-kit/panel-dock/-internals/panel";`
  );
  assert.deepEqual(messages, ["discourse/no-cross-group-internals"]);
});

test("one group cannot import another group's internals", () => {
  const messages = messagesFor(
    `${APP}/ui-kit/select/index.js`,
    `import PanelDockChassis from "discourse/ui-kit/panel-dock/-internals/panel";`
  );
  assert.deepEqual(messages, ["discourse/no-cross-group-internals"]);
});

test("a group may import its own internals relatively", () => {
  const messages = messagesFor(
    `${APP}/ui-kit/panel-dock/index.js`,
    `import PanelDockChassis from "./-internals/panel";`
  );
  assert.deepEqual(messages, []);
});

test("a group may import its own internals by absolute specifier", () => {
  const messages = messagesFor(
    `${APP}/ui-kit/panel-dock/index.js`,
    `import PanelDockChassis from "discourse/ui-kit/panel-dock/-internals/panel";`
  );
  assert.deepEqual(messages, []);
});

test("a nested internal module may import a sibling internal", () => {
  const messages = messagesFor(
    `${APP}/ui-kit/panel-dock/-internals/panel.js`,
    `import helper from "./layout.js";`
  );
  assert.deepEqual(messages, []);
});

test("test files are exempt", () => {
  const messages = messagesFor(
    "frontend/discourse/tests/integration/components/panel-dock/panel-test.js",
    `import PanelDockChassis from "discourse/ui-kit/panel-dock/-internals/panel";`
  );
  assert.deepEqual(messages, []);
});

test("a re-export reaches no further than an import", () => {
  const messages = messagesFor(
    `${APP}/components/composer.js`,
    `export { default } from "discourse/ui-kit/panel-dock/-internals/panel";`
  );
  assert.deepEqual(messages, ["discourse/no-cross-group-internals"]);
});

test("internals outside a ui-kit group are not this rule's business", () => {
  const messages = messagesFor(
    `${APP}/components/composer.js`,
    `import { meta } from "@ember/-internals/meta";`
  );
  assert.deepEqual(messages, []);
});

test("a literal dynamic import cannot bypass the boundary", () => {
  const messages = messagesFor(
    `${APP}/components/composer.js`,
    `const chassis = import("discourse/ui-kit/panel-dock/-internals/panel");`
  );
  assert.deepEqual(messages, ["discourse/no-cross-group-internals"]);
});

test("traversal after an internals segment cannot escape into another group", () => {
  const messages = messagesFor(
    `${APP}/ui-kit/select/index.js`,
    `import chassis from "./-internals/../../panel-dock/-internals/panel";`
  );
  assert.deepEqual(messages, ["discourse/no-cross-group-internals"]);
});

test("a template-literal dynamic import cannot bypass the boundary", () => {
  const messages = messagesFor(
    `${APP}/components/composer.js`,
    "const chassis = import(`discourse/ui-kit/panel-dock/-internals/panel`);"
  );
  assert.deepEqual(messages, ["discourse/no-cross-group-internals"]);
});

test("an interpolation cannot launder a fixed internals prefix", () => {
  const messages = messagesFor(
    `${APP}/components/composer.js`,
    "const chassis = import(`discourse/ui-kit/panel-dock/-internals/${name}`);"
  );
  assert.deepEqual(messages, ["discourse/no-cross-group-internals"]);
});

test("a fixed internals prefix stays importable from its own group", () => {
  const messages = messagesFor(
    `${APP}/ui-kit/panel-dock/index.js`,
    "const part = import(`./-internals/${name}`);"
  );
  assert.deepEqual(messages, []);
});

test("an interpolated group is beyond static analysis and skipped", () => {
  const messages = messagesFor(
    `${APP}/components/composer.js`,
    "const chassis = import(`discourse/ui-kit/${name}/-internals/panel`);"
  );
  assert.deepEqual(messages, []);
});

test("a partial trailing segment is not mistaken for an internals prefix", () => {
  const messages = messagesFor(
    `${APP}/components/composer.js`,
    "const chassis = import(`discourse/ui-kit/panel-dock/-inter${nals}`);"
  );
  assert.deepEqual(messages, []);
});

test("imports without an internals segment are untouched", () => {
  const messages = messagesFor(
    `${APP}/components/composer.js`,
    `import DPanelDock from "discourse/ui-kit/panel-dock";\nimport { internalsHelper } from "discourse/lib/internals-helper";`
  );
  assert.deepEqual(messages, []);
});
