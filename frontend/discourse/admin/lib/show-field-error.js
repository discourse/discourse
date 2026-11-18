export default function showFieldError(field, message) {
  if (!message || field.error?.messages.includes(message)) {
    return;
  }

  field.addError(field.name, { title: field.title, message });
}
