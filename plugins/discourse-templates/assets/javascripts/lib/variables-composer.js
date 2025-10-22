export default function extractVariablesFromComposerModel(model) {
  if (!model) {
    return {};
  }

  const composerVariables = {
    topic_title: model.topic?.title,
    topic_url: model.topic?.url,
    original_poster_username: model.topic?.details.created_by.username,
    original_poster_name: model.topic?.details.created_by.name,
    reply_to_username: model.post?.username,
    reply_to_name: model.post?.name,
    last_poster_username: model.topic?.last_poster_username,
    reply_to_or_last_poster_username:
      model.post?.username || model.topic?.last_poster_username,
  };

  return {
    ...composerVariables,
    context_title: composerVariables.topic_title,
    context_url: composerVariables.topic_url,
  };
}
