const basenames = new Set();
const listeners = new Set();

let observer;

// Call at boot, before the browser's resource timing buffer fills and drops entries.
export function startTrackingFetchedResources() {
  if (observer) {
    return;
  }

  observer = new PerformanceObserver((list) => {
    const added = [];
    for (const entry of list.getEntries()) {
      const name = basename(entry.name);
      if (!basenames.has(name)) {
        basenames.add(name);
        added.push(name);
      }
    }

    if (added.length) {
      listeners.forEach((listener) => listener(added));
    }
  });
  observer.observe({ type: "resource", buffered: true });
}

export function subscribeToFetchedResources(listener) {
  listeners.add(listener);
  listener([...basenames]);
  return () => listeners.delete(listener);
}

export function basename(url) {
  return url.split("?")[0].split("/").pop();
}
