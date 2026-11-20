import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { cook } from "discourse/lib/text";

const enabled = { siteSettings: { discourse_ai_enabled: true } };

async function cookedMarkup(input, options = enabled) {
  return (await cook(input, options)).toString();
}

function artifactElements(markup) {
  return [
    ...new DOMParser()
      .parseFromString(markup, "text/html")
      .querySelectorAll("div.ai-artifact"),
  ];
}

module("Unit | Lib | ai-artifact-markdown", function (hooks) {
  setupTest(hooks);

  test("standalone share token produces an artifact mount point", async function (assert) {
    for (const share of ["Ab_09-z", "a".repeat(128)]) {
      const [artifact] = artifactElements(
        await cookedMarkup(`[ai-artifact share="${share}"]`)
      );

      assert.true(!!artifact, `${share} renders the artifact div`);
      assert.strictEqual(
        artifact?.getAttribute("data-ai-artifact-share-key"),
        share,
        "preserves the share key"
      );
      assert.false(
        artifact?.hasAttribute("data-ai-artifact-id"),
        "does not add an id"
      );
    }
  });

  test("id and optional version produce artifact mount points without number coercion", async function (assert) {
    for (const [input, id, version] of [
      ['[ai-artifact id="123"]', "123", null],
      ['[ai-artifact id="123" version="2"]', "123", "2"],
      ['[ai-artifact id="123" version="0"]', "123", null],
      [
        '[ai-artifact id="9999999999999999999" version="1234567890123456789"]',
        "9999999999999999999",
        "1234567890123456789",
      ],
    ]) {
      const artifacts = artifactElements(await cookedMarkup(input));
      assert.strictEqual(artifacts.length, 1, `${input} renders once`);
      assert.strictEqual(
        artifacts[0]?.getAttribute("data-ai-artifact-id"),
        id,
        `${input} preserves id digits`
      );
      assert.strictEqual(
        artifacts[0]?.getAttribute("data-ai-artifact-version"),
        version,
        `${input} preserves version digits or omits zero`
      );
    }
  });

  test("explicit autorun booleans are preserved on both embed forms", async function (assert) {
    for (const [input, identifier] of [
      [
        '[ai-artifact share="key" autorun="true"]',
        "data-ai-artifact-share-key",
      ],
      [
        '[ai-artifact autorun="false" share="key"]',
        "data-ai-artifact-share-key",
      ],
      ['[ai-artifact id="7" autorun="true"]', "data-ai-artifact-id"],
      [
        '[ai-artifact autorun="false" version="2" id="7"]',
        "data-ai-artifact-id",
      ],
    ]) {
      const artifacts = artifactElements(await cookedMarkup(input));
      const [artifact] = artifacts;
      const expected = input.includes('autorun="true"') ? "true" : "false";
      assert.strictEqual(artifacts.length, 1, `${input} renders once`);
      assert.strictEqual(
        artifact?.getAttribute(identifier),
        identifier.includes("share") ? "key" : "7",
        `${input} retains the identifier`
      );
      assert.strictEqual(
        artifact?.getAttribute("data-ai-artifact-autorun"),
        expected,
        `${input} retains the explicit autorun value`
      );
    }

    for (const input of [
      '[ai-artifact share="key"]',
      '[ai-artifact id="7" version="2"]',
    ]) {
      const [artifact] = artifactElements(await cookedMarkup(input));
      assert.false(
        artifact?.hasAttribute("data-ai-artifact-autorun"),
        `${input} has no implicit autorun attribute`
      );
    }
  });

  test("height and seamless cook as constrained compact layout attributes", async function (assert) {
    for (const [input, identifier] of [
      [
        '[ai-artifact share="key" height="2000" seamless="true"]',
        "data-ai-artifact-share-key",
      ],
      [
        '[ai-artifact id="7" height="00042" seamless="false"]',
        "data-ai-artifact-id",
      ],
    ]) {
      const [artifact] = artifactElements(await cookedMarkup(input));
      assert.true(!!artifact, `${input} cooks to an artifact`);
      assert.true(artifact.hasAttribute(identifier), "identity is retained");
      assert.strictEqual(
        artifact.getAttribute("data-ai-artifact-height"),
        input.includes("2000") ? "2000" : "42",
        "height is canonical decimal"
      );
      assert.strictEqual(
        artifact.getAttribute("data-ai-artifact-seamless"),
        input.includes('seamless="true"') ? "true" : "false",
        "seamless is explicit"
      );
    }
  });

  test("works inside quotes and list items but not fenced or inline code", async function (assert) {
    for (const input of [
      '> [ai-artifact share="quoted"]',
      '- [ai-artifact id="7"]',
    ]) {
      assert.strictEqual(
        artifactElements(await cookedMarkup(input)).length,
        1,
        `${input} is parsed inside its markdown container`
      );
    }

    for (const input of [
      '`[ai-artifact id="7" autorun="true"]`',
      '```\n[ai-artifact share="key" autorun="false"]\n```',
      '    [ai-artifact id="7"]',
      '```html\n<div class="ai-artifact" data-ai-artifact-id="7" data-ai-artifact-width="600"></div>\n```',
      '- item\n\n      [ai-artifact id="7"]',
    ]) {
      assert.strictEqual(
        artifactElements(await cookedMarkup(input)).length,
        0,
        `${input} remains code`
      );
    }
  });

  test("only an entire standalone line is parsed, including adjacent blocks", async function (assert) {
    for (const input of [
      'Before [ai-artifact id="7"]',
      '[ai-artifact id="7"] after',
    ]) {
      assert.strictEqual(
        artifactElements(await cookedMarkup(input)).length,
        0,
        `${input} does not steal inline prose`
      );
    }

    for (const input of [
      'Before\n[ai-artifact id="7"]\nAfter',
      '[ai-artifact id="7"]\ncontinued prose',
      '# Heading\n[ai-artifact id="7"]\n- item',
      '[ai-artifact id="7"]\n# Heading',
      '- item\n[ai-artifact id="7"]',
      'Before\n\n[ai-artifact id="7"]\n\nAfter',
    ]) {
      const markup = await cookedMarkup(input);
      assert.strictEqual(
        artifactElements(markup).length,
        1,
        `${input} renders a whole-line tag`
      );
      assert.true(
        markup.includes('data-ai-artifact-id="7"'),
        `${input} preserves the mount point`
      );
    }
  });

  test("invalid or ambiguous attribute syntax is inert", async function (assert) {
    const invalid = [
      "[ai-artifact]",
      '[ai-artifact version="2"]',
      '[ai-artifact share="abc" id="3"]',
      '[ai-artifact share="abc" version="2"]',
      '[ai-artifact id="3" id="4"]',
      '[ai-artifact share="abc" share="def"]',
      '[ai-artifact id="3" width="100"]',
      '[ai-artifact id="3" autorun="true" autorun="false"]',
      '[ai-artifact share="key" autorun="false" autorun="false"]',
      '[ai-artifact share="key" autorun="true" width="100"]',
      '[ai-artifact share="key" seamless="1"]',
      '[ai-artifact id="3" seamless="TRUE"]',
      '[ai-artifact id="3" seamless="true" seamless="false"]',
      '[ai-artifact id="3" height="0"]',
      '[ai-artifact id="3" height="2001"]',
      '[ai-artifact id="3" height="-1"]',
      '[ai-artifact id="3" height="1.2"]',
      '[ai-artifact id="3" height="99999999999999999999"]',
      '[ai-artifact id="3" autorun=""]',
      '[ai-artifact id="3" autorun="1"]',
      '[ai-artifact id="3" autorun="TRUE"]',
      '[ai-artifact id="3" autorun="yes"]',
      '[ai-artifact share="key" autorun="0"]',
      '[ai-artifact share="key" autorun="false "]',
      '[ai-artifact id="3" autorun=true]',
      '[ai-artifact id="3" autorun="true" bare]',
      '[ai-artifact share=""]',
      `[ai-artifact share="${"a".repeat(129)}"]`,
      '[ai-artifact share="a/b"]',
      '[ai-artifact share="https://example.com/a"]',
      '[ai-artifact share="a\" onclick=\"bad"]',
      '[ai-artifact id="0"]',
      '[ai-artifact id="-1"]',
      '[ai-artifact id="1.2"]',
      '[ai-artifact id="12345678901234567890"]',
      '[ai-artifact id="3" version="-1"]',
      '[ai-artifact id="3" version="12345678901234567890"]',
      "[ai-artifact id=3]",
      "[ai-artifact id='3']",
    ];

    for (const input of invalid) {
      const markup = await cookedMarkup(input);
      assert.strictEqual(
        artifactElements(markup).length,
        0,
        `${input} is not an artifact`
      );
      assert.true(markup.includes("ai-artifact"), `${input} stays visible`);
    }
  });

  test("AI setting gates native syntax but not existing HTML allowlist", async function (assert) {
    const markup = await cookedMarkup('[ai-artifact id="3"]', {
      siteSettings: { discourse_ai_enabled: false },
    });
    assert.strictEqual(
      artifactElements(markup).length,
      0,
      "disabled AI does not parse native syntax"
    );

    const legacy = await cookedMarkup(
      '<div class="ai-artifact" data-ai-artifact-id="3" data-ai-artifact-version="2" data-ai-artifact-autorun="true" data-ai-artifact-height="400" data-ai-artifact-width="600" data-ai-artifact-seamless="true"></div>',
      { siteSettings: { discourse_ai_enabled: false } }
    );
    const [artifact] = artifactElements(legacy);
    for (const [name, value] of [
      ["data-ai-artifact-id", "3"],
      ["data-ai-artifact-version", "2"],
      ["data-ai-artifact-autorun", "true"],
      ["data-ai-artifact-height", "400"],
      ["data-ai-artifact-width", "600"],
      ["data-ai-artifact-seamless", "true"],
    ]) {
      assert.strictEqual(
        artifact?.getAttribute(name),
        value,
        `legacy HTML retains ${name}`
      );
    }
  });
});
