// Ambient shim for `@glimmer/manager`. The package ships its own types, but it
// is a transitive dependency with no resolvable entry point from the app, so
// `ember-tsc` cannot find the module (TS2307). Declare the two internal-manager
// helpers the block decorator relies on, typed just precisely enough to wrap the
// returned manager in a Proxy — the manager object itself is opaque here.
declare module "@glimmer/manager" {
  export function getInternalComponentManager(definition: object): object;

  export function setInternalComponentManager<T extends object>(
    manager: object,
    obj: T
  ): T;
}
