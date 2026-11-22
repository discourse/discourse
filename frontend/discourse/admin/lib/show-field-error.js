export default function showFieldError(field, message) {
  field.removeError();

  if (!message) {
    return;
  }

  field.addError(field.name, { title: field.title, message });
}
