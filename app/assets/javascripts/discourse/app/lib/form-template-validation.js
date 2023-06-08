export default function prepareFormTemplateData(form) {
  const formData = new FormData(form);

  // Validate the form template
  _validateFormTemplateData(form);
  if (!form.checkValidity()) {
    return false;
  }

  // Gather form template data
  const formDetails = [];
  for (let [key, value] of formData.entries()) {
    formDetails.push({
      [key]: value,
    });
  }

  const mergedData = [];
  const mergedKeys = new Set();

  for (const item of formDetails) {
    const key = Object.keys(item)[0]; // Get the key of the current item
    if (mergedKeys.has(key)) {
      // If the key has already been merged, append the value to the existing key
      mergedData[mergedData.length - 1][key] += "\n" + item[key];
    } else {
      mergedData.push(item);
      mergedKeys.add(key);
    }
  }

  // Construct formatted post output
  const formattedOutput = mergedData.map((item) => {
    const key = Object.keys(item)[0];
    const value = item[key];
    if (value) {
      return `### ${key}\n${value}`;
    }
  });

  return formattedOutput.join("\n\n");
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

      errorBox.textContent = field.validationMessage;
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
