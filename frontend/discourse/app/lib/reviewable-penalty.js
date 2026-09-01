import { i18n } from "discourse-i18n";

const LIFTS_PENALTY = "lifts_penalty";

export const SILENCE = "silence";
export const SUSPENSION = "suspension";

const PAST_TENSE = { [SILENCE]: "silenced", [SUSPENSION]: "suspended" };

const ICONS = { [SILENCE]: "microphone-slash", [SUSPENSION]: "ban" };

export function penaltyPastTense(kind) {
  return PAST_TENSE[kind];
}

export function penaltyIcon(kind) {
  return ICONS[kind];
}

export function penaltyEffectDescription(action, penalties) {
  if (!action?.penalty_effect || !penalties?.length) {
    return null;
  }

  if (action.penalty_effect === LIFTS_PENALTY) {
    return i18n("review.author_penalty.effect.lifts_silence");
  }

  const kinds = new Set(penalties.map((penalty) => penalty.kind));

  if (kinds.has(SILENCE) && kinds.has(SUSPENSION)) {
    return i18n("review.author_penalty.effect.retains_silence_and_suspension");
  }

  return kinds.has(SUSPENSION)
    ? i18n("review.author_penalty.effect.retains_suspension")
    : i18n("review.author_penalty.effect.retains_silence");
}
