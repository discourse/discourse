const waiters = new Set();

export function registerSplashScreenWaiter(callback) {
  waiters.add(callback);

  return function release() {
    waiters.delete(callback);
  };
}

export async function removeSplashScreen() {
  const promises = [...waiters].map((callback) => callback());

  await Promise.allSettled(promises);
  document.querySelector("#d-splash")?.remove();
}

export function __resetWaiters() {
  waiters.clear();
}
