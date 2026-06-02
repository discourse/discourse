let holds = new Map();

export function holdSplashScreen(name) {
  const token = Symbol(name);
  holds.set(token, name);

  return function release() {
    holds.delete(token);
    removeSplashScreen();
  };
}

export function removeSplashScreen() {
  if (holds.size > 0) {
    return;
  }

  document.querySelector("#d-splash")?.remove();
}

export function __resetHolds() {
  holds = new Map();
}
