export function buildDisclosure({
  workflow,
  nodeTypeFor,
  replaySteps = [],
  effects = [],
  preview = false,
}) {
  const nodes = (workflow?.nodes ?? []).filter(
    (node) => !node.type?.startsWith("trigger:")
  );

  const externalCalls = preview
    ? nodes
        .filter((node) => nodeTypeFor(node.type)?.simulation?.records)
        .map((node) => ({ name: node.name, replayed: false }))
    : replaySteps
        .filter((step) => step.kind === "external" && !step.needs_response)
        .map((step) => ({ name: step.name, replayed: true }));

  return {
    externalCalls,
    pinnedSteps: Object.keys(workflow?.pin_data ?? {}),
    unsupportedSteps: nodes
      .filter((node) => {
        const nodeType = nodeTypeFor(node.type);
        return nodeType && !nodeType.simulation;
      })
      .map((node) => node.name),
    liveActors: effects.length > 0,
  };
}
