import { module, test } from "qunit";
import { cardArgs } from "discourse/blocks/-internals/card-args";
import {
  buildValidationRule,
  groupFields,
  isFieldVisible,
  schemaToFields,
} from "discourse/plugins/discourse-wireframe/discourse/lib/layout/schema-to-fields";

module("Unit | Discourse Wireframe | Card inspector metadata", function () {
  function visibleNames(overrides = {}) {
    const values = Object.fromEntries(
      Object.entries(cardArgs).map(([name, schema]) => [name, schema.default])
    );
    Object.assign(values, overrides);
    return schemaToFields(cardArgs)
      .filter((field) => isFieldVisible(field, values))
      .map((field) => field.name);
  }

  test("optional groups are disclosures and disabled features do not crowd the form", function (assert) {
    const groups = groupFields(schemaToFields(cardArgs));
    assert.deepEqual(
      groups.filter((group) => group.disclosure).map((group) => group.group),
      ["label", "identity", "actions", "appearance", "advanced"],
      "optional groups share stable disclosure identities"
    );
    assert.true(
      groups
        .filter((group) => group.disclosure)
        .every((group) => group.collapsed),
      "optional groups start closed"
    );
    const names = visibleNames();
    for (const name of [
      "title",
      "body",
      "presentation",
      "image",
      "identityEnabled",
      "secondaryEnabled",
    ]) {
      assert.true(names.includes(name), `${name} remains discoverable`);
    }
    for (const name of [
      "imageWidth",
      "imageSide",
      "identityName",
      "avatar",
      "identityTreatment",
      "secondaryLabel",
      "linkLabel",
      "imageAlt",
    ]) {
      assert.false(names.includes(name), `${name} is hidden while inactive`);
    }
  });

  test("composition and identity controls follow independent saved preferences", function (assert) {
    const values = {
      presentation: "above",
      image: { url: "/feature.png" },
      identityEnabled: true,
      avatarDisplay: "initials",
      identityPlacement: "media",
    };
    const names = visibleNames(values);
    for (const name of [
      "identityName",
      "identityRole",
      "avatarDisplay",
      "identityFormat",
      "identityPlacement",
      "identityTreatment",
      "identityShape",
    ]) {
      assert.true(
        names.includes(name),
        `${name} is available for media identity`
      );
    }
    assert.false(
      names.includes("avatar"),
      "initials do not require an image control"
    );
    assert.true(
      visibleNames({ ...values, avatarDisplay: "image" }).includes("avatar"),
      "portrait image has its own control"
    );
    const beside = visibleNames({ ...values, presentation: "beside" });
    assert.true(beside.includes("imageWidth"), "Beside offers its split");
    assert.true(beside.includes("imageSide"), "Beside offers logical side");
    assert.false(
      beside.includes("identityPlacement"),
      "unsupported placement stays saved but is not offered"
    );
    assert.false(
      beside.includes("identityTreatment"),
      "content identity has no media treatment"
    );
    assert.false(
      visibleNames({ ...values, presentation: "none" }).includes("image"),
      "hidden media retains data without showing the control"
    );
  });

  test("whole-card naming and image accessibility expose only applicable controls", function (assert) {
    assert.true(
      visibleNames({ wholeCard: true }).includes("linkLabel"),
      "a whole-card link can have an explicit name"
    );
    assert.false(
      visibleNames({ wholeCard: true, actionLabel: "Read more" }).includes(
        "linkLabel"
      ),
      "visible action supplies the name"
    );
    assert.true(
      visibleNames({ secondaryEnabled: true }).includes("secondaryHref"),
      "secondary-only actions remain editable"
    );
    const values = { image: { url: "/feature.png" }, imageDecorative: false };
    assert.true(
      visibleNames(values).includes("imageAlt"),
      "informative media offers alt text"
    );
    assert.false(
      visibleNames({ ...values, imageDecorative: true }).includes("imageAlt"),
      "decorative media does not ask for alt text"
    );
    assert.false(
      visibleNames({ ...values, presentation: "none" }).includes("imageAlt"),
      "inactive media does not ask for alt text"
    );
  });
});

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

  test("propagates translated enum option labels", function (assert) {
    const fields = schemaToFields({
      surface: {
        type: "string",
        enum: ["transparent", "subtle"],
        ui: {
          control: "segmented",
          optionLabels: {
            transparent: "Transparent",
            subtle: "Subtle",
          },
        },
      },
    });

    assert.deepEqual(fields[0].optionLabels, {
      transparent: "Transparent",
      subtle: "Subtle",
    });
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
  test("inspector metadata: disclosures combine independent descriptors by stable name", function (assert) {
    const group = { name: "identity", label: "Speaker", collapsed: true };
    const groups = groupFields(
      schemaToFields({
        title: { type: "string", ui: { group: "Content" } },
        name: { type: "string", ui: { group } },
        role: { type: "string", ui: { group: { ...group } } },
      })
    );
    assert.strictEqual(groups.length, 2);
    assert.strictEqual(groups[1].group, "identity");
    assert.strictEqual(groups[1].label, "Speaker");
    assert.true(groups[1].disclosure);
    assert.true(groups[1].collapsed);
    assert.false(groups[0].disclosure);
    assert.deepEqual(
      groups[1].fields.map((field) => field.name),
      ["name", "role"]
    );
  });
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
  test("inspector metadata: compound visibility requires every leaf and compares oneOf strictly", function (assert) {
    const field = {
      conditional: {
        all: [
          { arg: "enabled", equals: true },
          { arg: "presentation", oneOf: ["above", "below"] },
          { arg: "name", notEmpty: true },
        ],
      },
    };
    const values = { enabled: true, presentation: "below", name: "Sam" };
    assert.true(isFieldVisible(field, values));
    assert.false(isFieldVisible(field, { ...values, enabled: false }));
    assert.false(isFieldVisible(field, { ...values, presentation: "beside" }));
    assert.false(isFieldVisible(field, { ...values, name: "" }));
    assert.false(isFieldVisible(field, {}));
    const oneOf = { conditional: { arg: "count", oneOf: [0, 2] } };
    assert.true(isFieldVisible(oneOf, { count: 0 }));
    assert.false(isFieldVisible(oneOf, { count: "0" }));
  });
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
