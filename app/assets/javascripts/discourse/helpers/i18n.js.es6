import registerUnbound from 'discourse/helpers/register-unbound';

registerUnbound('i18n', function(key, params) {
  return I18n.t(key, params);
});
