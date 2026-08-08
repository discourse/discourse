import { module, test } from "qunit";
import {
  buildValidationRule,
  groupFields,
  isFieldVisible,
  schemaToFields,
} from "discourse/plugins/discourse-wireframe/discourse/lib/layout/schema-to-fields";

module("Unit | Discourse Wireframe | schemaToFields", function () {
  test("returns an empty list for null/undefined/non-object schemas", function (assert) {
    assert.deepEqual(schemaToFields(null), []);
    assert.deepEqual(schemaToFields(undefined), []);
    assert.deepEqual(schemaToFields("nope"), []);
  });

  test("maps a string arg to a text control by default", function (assert) {
    const fields = schemaToFields({ title: { type: "string" } });
    assert.strictEqual(fields.length, 1);
    assert.strictEqual(fields[0].control, "text");
    assert.strictEqual(fields[0].name, "title");
    assert.strictEqual(
      fields[0].title,
      "Title",
      "default title is title-cased"
    );
    assert.strictEqual(fields[0].group, "General");
    assert.false(fields[0].required);
  });

  test("maps a long string (maxLength > 200) to a textarea", function (assert) {
    const fields = schemaToFields({
      body: { type: "string", maxLength: 1000 },
    });
    assert.strictEqual(fields[0].control, "textarea");
  });

  test("maps a string with enum to a select with options", function (assert) {
    const fields = schemaToFields({
      size: { type: "string", enum: ["small", "large"] },
    });
    assert.strictEqual(fields[0].control, "select");
    assert.deepEqual(fields[0].options, ["small", "large"]);
  });

  test("maps a number arg to a number control", function (assert) {
    const fields = schemaToFields({ count: { type: "number" } });
    assert.strictEqual(fields[0].control, "number");
  });

  test("maps a boolean arg to a toggle", function (assert) {
    const fields = schemaToFields({ enabled: { type: "boolean" } });
    assert.strictEqual(fields[0].control, "toggle");
  });

  test("maps a string-array arg to a tag-chooser", function (assert) {
    const fields = schemaToFields({
      tags: { type: "array", itemType: "string" },
    });
    assert.strictEqual(fields[0].control, "tag-chooser");
  });

  test("maps a non-string array to a text control (fallback)", function (assert) {
    const fields = schemaToFields({
      ids: { type: "array", itemType: "number" },
    });
    assert.strictEqual(fields[0].control, "text");
  });

  test("maps an array-of-object arg to the repeatable control", function (assert) {
    const fields = schemaToFields({
      items: {
        type: "array",
        itemType: "object",
        itemSchema: {
          label: { type: "string" },
          url: { type: "string" },
        },
      },
    });
    assert.strictEqual(fields[0].control, "repeatable");
    assert.deepEqual(
      Object.keys(fields[0].schema.itemSchema),
      ["label", "url"],
      "the item schema is preserved on the field descriptor for the control"
    );
  });

  test("maps `any` to a code editor", function (assert) {
    const fields = schemaToFields({ data: { type: "any" } });
    assert.strictEqual(fields[0].control, "code");
  });

  test("`ui.control` overrides the default mapping", function (assert) {
    const fields = schemaToFields({
      accentColor: { type: "string", ui: { control: "color" } },
      avatarHref: { type: "string", ui: { control: "url" } },
    });
    assert.strictEqual(fields[0].control, "color");
    assert.strictEqual(fields[1].control, "url");
  });

  test("type:image resolves to the custom image control regardless of ui.control", function (assert) {
    const fields = schemaToFields({
      cover: { type: "image", allowDark: true },
      avatar: { type: "image", ui: { control: "color" } },
    });
    assert.strictEqual(fields[0].control, "image");
    assert.strictEqual(
      fields[1].control,
      "image",
      "type:image wins over any stray ui.control hint"
    );
  });

  test("propagates ui label, placeholder, helpText, group, required, default", function (assert) {
    const fields = schemaToFields({
      title: {
        type: "string",
        required: true,
        default: "Welcome",
        ui: {
          label: "Page title",
          placeholder: "e.g. Welcome",
          helpText: "Shown at the top.",
          group: "Content",
        },
      },
    });
    const f = fields[0];
    assert.strictEqual(f.title, "Page title");
    assert.strictEqual(f.placeholder, "e.g. Welcome");
    assert.strictEqual(f.helpText, "Shown at the top.");
    assert.strictEqual(f.group, "Content");
    assert.true(f.required);
    assert.strictEqual(f.default, "Welcome");
  });

  test("omits args with `ui.hidden: true`", function (assert) {
    const fields = schemaToFields({
      visible: { type: "string" },
      hidden: { type: "string", ui: { hidden: true } },
    });
    assert.strictEqual(fields.length, 1);
    assert.strictEqual(fields[0].name, "visible");
  });

  test("preserves schema key order in the output", function (assert) {
    const fields = schemaToFields({
      z: { type: "string" },
      a: { type: "string" },
      m: { type: "string" },
    });
    assert.deepEqual(
      fields.map((f) => f.name),
      ["z", "a", "m"]
    );
  });

  test("title-cases hyphenated and snake_cased names", function (assert) {
    const fields = schemaToFields({
      "cta-label": { type: "string" },
      cta_url: { type: "string" },
      ctaLabel: { type: "string" },
    });
    assert.strictEqual(fields[0].title, "Cta Label");
    assert.strictEqual(fields[1].title, "Cta Url");
    assert.strictEqual(fields[2].title, "Cta Label");
  });
});

module("Unit | Discourse Wireframe | groupFields", function () {
  test("groups by `group`, preserving first-seen order", function (assert) {
    const fields = schemaToFields({
      title: { type: "string", ui: { group: "Content" } },
      bg: { type: "string", ui: { group: "Appearance" } },
      body: { type: "string", ui: { group: "Content" } },
      misc: { type: "string" },
    });
    const groups = groupFields(fields);
    assert.deepEqual(
      groups.map((g) => g.group),
      ["Content", "Appearance", "General"]
    );
    assert.deepEqual(
      groups[0].fields.map((f) => f.name),
      ["title", "body"]
    );
  });

  test("returns an empty list for empty input", function (assert) {
    assert.deepEqual(groupFields([]), []);
  });
});

module("Unit | Discourse Wireframe | isFieldVisible", function () {
  test("returns true when the field has no conditional", function (assert) {
    const [field] = schemaToFields({ a: { type: "string" } });
    assert.true(isFieldVisible(field, {}));
  });

  test("`equals` matches exactly", function (assert) {
    const [field] = schemaToFields({
      url: {
        type: "string",
        ui: { conditional: { arg: "label", equals: "Buy" } },
      },
    });
    assert.true(isFieldVisible(field, { label: "Buy" }));
    assert.false(isFieldVisible(field, { label: "Sell" }));
    assert.false(isFieldVisible(field, {}));
  });

  test("`notEmpty` treats null, '', and false as empty", function (assert) {
    const [field] = schemaToFields({
      url: {
        type: "string",
        ui: { conditional: { arg: "label", notEmpty: true } },
      },
    });
    assert.true(isFieldVisible(field, { label: "x" }));
    assert.false(isFieldVisible(field, { label: "" }));
    assert.false(isFieldVisible(field, { label: null }));
    assert.false(isFieldVisible(field, { label: false }));
    assert.false(isFieldVisible(field, {}));
  });
});

module("Unit | Discourse Wireframe | buildValidationRule", function () {
  test("returns undefined when no constraints apply", function (assert) {
    const [field] = schemaToFields({ title: { type: "string" } });
    assert.strictEqual(buildValidationRule(field), undefined);
  });

  test("emits `required` when the schema declares required: true", function (assert) {
    const [field] = schemaToFields({
      title: { type: "string", required: true },
    });
    assert.strictEqual(buildValidationRule(field), "required");
  });

  test("emits `length:min,max` only when both bounds are declared", function (assert) {
    const [withBoth] = schemaToFields({
      title: { type: "string", minLength: 1, maxLength: 50 },
    });
    assert.strictEqual(buildValidationRule(withBoth), "length:1,50");

    const [onlyMin] = schemaToFields({
      title: { type: "string", minLength: 1 },
    });
    assert.strictEqual(
      buildValidationRule(onlyMin),
      undefined,
      "no fake max — schema didn't declare one"
    );
  });

  test("emits `between:min,max` only when both bounds are declared", function (assert) {
    const [withBoth] = schemaToFields({
      gap: { type: "number", min: 0, max: 4 },
    });
    assert.strictEqual(buildValidationRule(withBoth), "between:0,4");

    const [onlyMin] = schemaToFields({
      gap: { type: "number", min: 0 },
    });
    assert.strictEqual(buildValidationRule(onlyMin), undefined);
  });

  test("combines multiple rules pipe-joined", function (assert) {
    const [field] = schemaToFields({
      title: {
        type: "string",
        required: true,
        minLength: 1,
        maxLength: 50,
      },
    });
    assert.strictEqual(buildValidationRule(field), "required|length:1,50");
  });
});
