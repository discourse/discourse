export function setTextareaSelection(textarea, selectionStart, selectionEnd) {
  textarea.selectionStart = selectionStart;
  textarea.selectionEnd = selectionEnd;
}

export function getTextareaSelection(textarea) {
  const start = textarea.selectionStart;
  const end = textarea.selectionEnd;
  return [start, end - start];
}
