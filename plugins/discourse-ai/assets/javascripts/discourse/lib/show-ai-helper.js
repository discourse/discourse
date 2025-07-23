export function showComposerAiHelper(
  composerModel,
  siteSettings,
  currentUser,
  featureType
) {
  const enableHelper = _helperEnabled(siteSettings);
  const enableAssistant = currentUser.can_use_assistant;
  const canShowInPM = siteSettings.ai_helper_allowed_in_pm;
  const enableFeature =
    siteSettings.ai_helper_enabled_features.includes(featureType);

  if (composerModel?.privateMessage) {
    return enableHelper && enableAssistant && canShowInPM && enableFeature;
  }

  return enableHelper && enableAssistant && enableFeature;
}

export function showPostAIHelper(outletArgs, helper) {
  return (
    _helperEnabled(helper.siteSettings) &&
    helper.currentUser?.can_use_assistant_in_post
  );
}

function _helperEnabled(siteSettings) {
  return siteSettings.discourse_ai_enabled && siteSettings.ai_helper_enabled;
}
