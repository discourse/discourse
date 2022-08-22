let PROCESSORS_MAP = {};

export function findUserMenuListProcessors(listType) {
  return PROCESSORS_MAP[listType] || [];
}

export function registerUserMenuListProcessor(listType, processor) {
  if (!PROCESSORS_MAP[listType]) {
    PROCESSORS_MAP[listType] = [];
  }
  PROCESSORS_MAP[listType].push(processor);
}

export function resetUserMenuListProcessors() {
  PROCESSORS_MAP = {};
}
