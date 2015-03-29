import registerUnbound from 'discourse/helpers/register-unbound';

const Safe = Handlebars.SafeString;

registerUnbound('user-status', function(user) {
  if (!user) { return; }

  var name = Handlebars.Utils.escapeExpression(user.get('name'));

  if(Discourse.User.currentProp("admin") || Discourse.User.currentProp("moderator")) {
    if(user.get('admin')) {
      var adminDesc = I18n.t('user.admin', {user: name});
      return new Safe('<i class="fa fa-shield" title="' + adminDesc +  '" alt="' + adminDesc + '"></i>');
    }
  }
  if(user.get('moderator')){
    var modDesc = I18n.t('user.moderator', {user: name});
    return new Safe('<i class="fa fa-shield" title="' + modDesc +  '" alt="' + modDesc + '"></i>');
  }
});
