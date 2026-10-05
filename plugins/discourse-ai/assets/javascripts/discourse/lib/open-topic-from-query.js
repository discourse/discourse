import { ajax } from "discourse/lib/ajax";
import { tagNames, tagSuggestionParams } from "./ai-helper-suggestions";
import { showComposerAiHelper } from "./show-ai-helper";

async function requestSuggestion(url, data) {
  try {
    return await ajax(url, { type: "POST", data });
  } catch {
    return null;
  }
}

async function enrichNewTopic({
  model,
  query,
  suggestTitle,
  suggestTaxonomy,
  canTagTopics,
  maxTitleLength,
}) {
  const initialTitle = model.title;
  const initialCategoryId = model.categoryId;
  const initialTags = tagNames(model.tags);
  const titleRequest = suggestTitle
    ? requestSuggestion("/discourse-ai/ai-helper/suggest_title", {
        text: query,
      })
    : null;
  const categoryRequest = suggestTaxonomy
    ? requestSuggestion("/discourse-ai/ai-helper/suggest_category", {
        text: query,
      })
    : null;
  const [titleResult, categoryResult] = await Promise.all([
    titleRequest,
    categoryRequest,
  ]);

  const suggestedTitle = titleResult?.suggestions?.[0]?.trim();
  if (suggestedTitle && model.title === initialTitle) {
    model.set("title", suggestedTitle.slice(0, maxTitleLength));
  }

  const suggestedCategory = categoryResult?.assistant?.[0];
  if (suggestedCategory && model.categoryId === initialCategoryId) {
    model.set("categoryId", suggestedCategory.id);
  }

  if (
    !suggestTaxonomy ||
    !canTagTopics ||
    tagNames(model.tags).join("\0") !== initialTags.join("\0")
  ) {
    return;
  }

  const tagResult = await requestSuggestion(
    "/discourse-ai/ai-helper/suggest_tags",
    {
      text: query,
      ...tagSuggestionParams(model.categoryId, model.tags),
    }
  );
  const suggestedTags = tagResult?.assistant
    ?.map((tag) => tag.name)
    .filter(Boolean);

  if (
    suggestedTags?.length &&
    tagNames(model.tags).join("\0") === initialTags.join("\0")
  ) {
    model.set("tags", suggestedTags);
  }
}

/**
 * Opens the composer for a new topic asking the query, then fills in the AI
 * helper's suggested title, category and tags where they are enabled.
 */
export async function openTopicFromQuery({
  composer,
  currentUser,
  query,
  siteSettings,
}) {
  await composer.openNewTopic({ title: query });

  const model = composer.model;
  const suggestionsEnabled = showComposerAiHelper(
    model,
    siteSettings,
    currentUser,
    "suggestions"
  );

  await enrichNewTopic({
    model,
    query,
    suggestTitle: suggestionsEnabled,
    suggestTaxonomy: suggestionsEnabled && siteSettings.ai_embeddings_enabled,
    canTagTopics: currentUser.can_tag_topics,
    maxTitleLength: siteSettings.max_topic_title_length,
  });
}
