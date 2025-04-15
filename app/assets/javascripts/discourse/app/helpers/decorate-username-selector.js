import { htmlSafe } from "@ember/template";

let usernameDecorators = [];
export function addUsernameSelectorDecorator(decorator) {
  usernameDecorators.push(decorator);
}

export function resetUsernameDecorators() {
  usernameDecorators = [];
}

export function decorateUsername(username) {
  const decorations = [];

  usernameDecorators.forEach((decorator) => {
    decorations.push(decorator(username));
  });

  return decorations.length ? htmlSafe(decorations.join("")) : "";
}

export default function decorateUsernameSelector(username) {
  return decorateUsername(username);
}
