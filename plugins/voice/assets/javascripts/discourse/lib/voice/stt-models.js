import { i18n } from "discourse-i18n";

// The selectable speech-to-text models. Each is a folder holding the
// worker's fixed file layout (encoder-model.onnx,
// decoder_joint-model.int8.onnx, vocab.txt) under one model root: a site's
// mirror (voice_stt_model_base_url) or Discourse's HuggingFace repository.
// The default root is pinned to a commit because the worker caches by URL:
// updated weights must arrive under a new URL to ever be downloaded.
//
// Order here is the order shown in the selector.
export const STT_MODELS = {
  ultra: { path: "ultra-q4" },
  redux: { path: "redux-w2a8" },
};

export const DEFAULT_STT_MODEL = "ultra";

const DEFAULT_MODEL_ROOT =
  "https://huggingface.co/Discourse/Discourse-STT/resolve/0862913c8a5c08254d1082747c6443a06e062988";

const STORAGE_KEY = "voice:stt-model";

export function isSttModel(model) {
  return Object.hasOwn(STT_MODELS, model);
}

export function sttModelUrl(model, modelRoot) {
  const root = (modelRoot || DEFAULT_MODEL_ROOT).replace(/\/$/, "");
  return `${root}/${STT_MODELS[model].path}`;
}

export function preferredSttModel() {
  try {
    const model = localStorage.getItem(STORAGE_KEY);
    if (isSttModel(model)) {
      return model;
    }
  } catch {
    // fall through to the default
  }
  return DEFAULT_STT_MODEL;
}

export function setPreferredSttModel(model) {
  if (!isSttModel(model)) {
    return;
  }
  try {
    localStorage.setItem(STORAGE_KEY, model);
  } catch {
    // ignore storage errors
  }
}

export function sttModelLabel(model) {
  return i18n(`voice.voice_settings.subtitles_models.${model}`);
}
