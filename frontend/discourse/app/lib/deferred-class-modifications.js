// A `modifyClass` call can name a class whose module has not loaded yet. Route bundles flush
// these when they arrive; a component registers itself, because nothing else registers it.

const pendingModifications = new Map();
const lazyClasses = new Map();

export function lazyClassFor(resolverName) {
  const klass = lazyClasses.get(resolverName);

  return klass ? { class: klass } : null;
}

export function deferClassModification(resolverName, pendingModification) {
  const modifications = pendingModifications.get(resolverName) ?? [];

  modifications.push(pendingModification);
  pendingModifications.set(resolverName, modifications);
}

// Appended to every plugin and theme component module by `discourse-register-components`.
export function registerModuleForModifyClass(path, klass) {
  const resolverName = `component:${path}`;

  lazyClasses.set(resolverName, klass);
  applyPending(resolverName);
}

export function resetDeferredClassModifications() {
  pendingModifications.clear();
}

// Route modules arrive as a batch through `Resolver#addModules` rather than one at a time.
export function applyDeferredClassModifications() {
  for (const resolverName of [...pendingModifications.keys()]) {
    applyPending(resolverName);
  }
}

// Taking them off first is what stops one that defers again from looping.
function applyPending(resolverName) {
  const modifications = pendingModifications.get(resolverName);

  if (!modifications) {
    return;
  }

  pendingModifications.delete(resolverName);

  for (const pendingModification of modifications) {
    pendingModification();
  }
}
