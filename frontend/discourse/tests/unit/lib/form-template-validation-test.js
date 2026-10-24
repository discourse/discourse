import { module, test } from "qunit";
import { collectFormTemplateAnswers } from "discourse/lib/form-template-validation";

module("Unit | Lib | form-template-validation", function () {
  test("collects typed values without flattening collections or multiline text", function (assert) {
    const form = document.createElement("form");
    const fields = [
      { id: "checked", type: "checkbox" },
      { id: "unchecked", type: "checkbox" },
      { id: "number", type: "input", validations: { type: "number" } },
      { id: "empty-number", type: "input", validations: { type: "number" } },
      { id: "missing", type: "input" },
      { id: "description", type: "composer" },
      { id: "games", type: "multi-select" },
    ];
    for (const [name, value, type] of [
      ["checked", "on", "checkbox"],
      ["number", "1e2", "number"],
      ["empty-number", "", "number"],
      ["description", "First\n\n**Second**", "textarea"],
      ["games", "First", "text"],
      ["games", "Second", "text"],
    ]) {
      const control = document.createElement(
        type === "textarea" ? "textarea" : "input"
      );
      control.name = name;
      if (type !== "textarea") {
        control.type = type;
      }
      control.value = value;
      control.checked = true;
      form.append(control);
    }

    const answers = collectFormTemplateAnswers(form, fields, false);

    assert.deepEqual(
      { ...answers },
      {
        checked: true,
        unchecked: false,
        number: "1e2",
        "empty-number": "",
        description: "First\n\n**Second**",
        games: ["First", "Second"],
      },
      "collects typed answers, keeps numeric spelling, omits missing controls"
    );
  });

  test("blocks invalid required fields before submission", function (assert) {
    const form = document.createElement("form");
    const control = document.createElement("input");
    control.id = "required-control";
    control.name = "required";
    control.required = true;
    form.append(control);

    assert.strictEqual(
      collectFormTemplateAnswers(form, [{ id: "required", type: "input" }]),
      null,
      "invalid values prevent rendering and submission"
    );
  });
});
