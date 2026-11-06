import { ajax } from "discourse/lib/ajax";
import { cloneJSON, deepEqual } from "discourse/lib/object";
import { i18n } from "discourse-i18n";

const initialValues = new WeakMap();

export function initializeFormTemplateAnswers(form, fields, values) {
  initialValues.delete(form);
  if (values) {
    initialValues.set(form, {
      saved: cloneJSON(values),
      displayed: collectFormTemplateAnswers(form, fields, false),
    });
  }
}

export function collectFormTemplateAnswers(
  form,
  fields,
  checkFormValidity = true
) {
  if (!form || !fields) {
    return null;
  }
  if (checkFormValidity) {
    _validateFormTemplateData(form);
    if (!form.checkValidity()) {
      return null;
    }
  }

  const formData = new FormData(form);
  const answers = Object.create(null);

  for (const field of fields) {
    const values = formData.getAll(field.id);
    if (field.type === "checkbox") {
      answers[field.id] = values.length > 0;
    } else if (values.length > 0) {
      answers[field.id] =
        field.type === "multi-select" ||
        (field.type === "tag-chooser" && field.attributes?.multiple)
          ? values
          : values[0];
    }
  }

  const initial = initialValues.get(form);
  if (initial) {
    for (const { id } of fields) {
      if (deepEqual(answers[id], initial.displayed[id])) {
        if (Object.hasOwn(initial.saved, id)) {
          answers[id] = initial.saved[id];
        } else {
          delete answers[id];
        }
      }
    }
  }
  return answers;
}

export default async function renderFormTemplate(
  form,
  fields,
  id,
  categoryId,
  checkFormValidity = true,
  postId
) {
  const answers = collectFormTemplateAnswers(form, fields, checkFormValidity);
  if (!answers) {
    return null;
  }
  const payload = JSON.stringify({ id, answers });
  const { raw } = await ajax("/form-templates/render.json", {
    type: "POST",
    data: {
      category_id: categoryId,
      post_id: postId,
      form_template_data: payload,
    },
  });
  return { raw, payload };
}

function _validateFormTemplateData(form) {
  const fields = Array.from(form.elements);

  fields.forEach((field) => {
    field.setAttribute("aria-invalid", false);

    const errorBox = document.createElement("div");
    errorBox.classList.add("form-template-field__error", "popup-tip");
    const errorId = field.id + "-error";

    field.addEventListener("invalid", () => {
      field.setAttribute("aria-invalid", true);
      errorBox.classList.add("bad");
      errorBox.setAttribute("id", errorId);
      field.setAttribute("aria-describedby", errorId);

      if (!field.nextElementSibling) {
        field.insertAdjacentElement("afterend", errorBox);
      }

      _showErrorMessage(field, errorBox);
    });

    // Mark the field as valid as changed:
    field.addEventListener("input", () => {
      const valid = field.checkValidity();
      if (valid) {
        field.setAttribute("aria-invalid", false);
        errorBox.classList.remove("bad");

        errorBox.textContent = "";
      }
    });

    field.addEventListener("blur", () => {
      field.checkValidity();
    });
  });
}

function _showErrorMessage(field, element) {
  if (field.validity.valueMissing) {
    const prefix = "form_templates.errors.value_missing";
    const types = ["select-one", "select-multiple", "checkbox"];

    const i18nMappings = {
      "select-one": "select_one",
      "select-multiple": "select_multiple",
    };

    _showErrorByType(element, field, prefix, types, i18nMappings);
  } else if (field.validity.typeMismatch) {
    const prefix = "form_templates.errors.type_mismatch";
    const types = [
      "color",
      "date",
      "email",
      "number",
      "password",
      "tel",
      "text",
      "url",
    ];
    _showErrorByType(element, field, prefix, types);
  } else if (field.validity.tooShort) {
    element.textContent = i18n("form_templates.errors.too_short", {
      count: field.minLength,
    });
  } else if (field.validity.tooLong) {
    element.textContent = i18n("form_templates.errors.too_long", {
      count: field.maxLength,
    });
  } else if (field.validity.rangeOverflow) {
    element.textContent = i18n("form_templates.errors.range_overflow", {
      count: field.max,
    });
  } else if (field.validity.rangeUnderflow) {
    element.textContent = i18n("form_templates.errors.range_underflow", {
      count: field.min,
    });
  } else if (field.validity.patternMismatch) {
    element.textContent = i18n("form_templates.errors.pattern_mismatch");
  } else if (field.validity.badInput) {
    element.textContent = i18n("form_templates.errors.bad_input");
  }
}

function _showErrorByType(element, field, prefix, types, i18nMappings) {
  if (!types.includes(field.type)) {
    element.textContent = i18n(`${prefix}.default`);
  } else {
    types.forEach((type) => {
      if (field.type === type) {
        element.textContent = i18n(
          `${prefix}.${
            i18nMappings && i18nMappings[type] ? i18nMappings[type] : type
          }`
        );
      }
    });
  }
}
