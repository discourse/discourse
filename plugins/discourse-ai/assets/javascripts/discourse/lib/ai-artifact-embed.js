export function formatAiArtifactPostEmbed(item) {
  if (item.type === "conversation") {
    const version =
      Number(item.artifact_version) > 0
        ? ` version="${item.artifact_version}"`
        : "";
    return `[ai-artifact id="${item.artifact_id}"${version}]`;
  }

  return `[ai-artifact share="${item.share_key}"]`;
}
