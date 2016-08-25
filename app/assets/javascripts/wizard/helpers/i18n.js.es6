import { registerUnbound } from 'discourse/lib/helpers';

registerUnbound('i18n', (key, params) => I18n.t(key, params));
