/* global __Ruby */
const I18n = { t: (a, b) => __Ruby.t(a, b) };

export default I18n;
export const i18n = I18n.t;
