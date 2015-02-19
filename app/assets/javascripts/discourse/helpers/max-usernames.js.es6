import registerUnbound from 'discourse/helpers/register-unbound';

registerUnbound('max-usernames', function(usernames, params) {
  var maxLength = parseInt(params.max) || 3;
  if (usernames.length > maxLength){
    return usernames.slice(0, maxLength).join(", ") + ", +" + (usernames.length - maxLength);
  } else {
    return usernames.join(", ");
  }
});
