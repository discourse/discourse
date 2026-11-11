const SETUP_LINKS = {
  no_image_generation_tool: {
    route: "adminPlugins.show.discourse-ai-tools.index",
    query: { presetCategory: "image_generation" },
  },
  no_embedding_model: {
    route: "adminPlugins.show.discourse-ai-models.new",
    query: { type: "embedding" },
  },
};

/**
 * Where to go to create what a feature needs, keyed by the setup note the
 * server reports for it.
 *
 * @param {string} [noteKey]
 * @returns {{ route: string, query: Object } | undefined}
 */
export function setupLink(noteKey) {
  return SETUP_LINKS[noteKey];
}
