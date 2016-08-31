import { registerUnbound } from 'discourse-common/lib/helpers';

registerUnbound('i18n', (key, params) => I18n.t(key, params));
