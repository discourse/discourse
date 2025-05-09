export function isValidInput(eventKey) {
  // relying on passing the event to the input is risky as it could not work
  // dispatching the event won't work as the event won't be trusted
  // safest solution is to filter event and prefill filter with it
  const nonInputKeysRegex =
    /F\d+|Arrow.+|Meta|Alt|Control|Shift|Delete|Enter|Escape|Tab|Space|Insert|Backspace/;
  return !nonInputKeysRegex.test(eventKey);
}

export function isNumeric(input) {
  return !isNaN(parseFloat(input)) && isFinite(input);
}

export function normalize(input) {
  if (input) {
    input = input.toLowerCase();

    if (typeof input.normalize === "function") {
      input = input.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    }
  }

  return input;
}
