/**
  Support for quoting other users.
**/

var esc = Handlebars.Utils.escapeExpression;

Discourse.Dialect.replaceBlock({
  start: new RegExp("\\[quote(=[^\\[\\]]+)?\\]([\\s\\S]*)", "igm"),
  stop: '[/quote]',
  emitter: function(blockContents, matches, options) {

    var params = {'class': 'quote'},
        username = null;

    if (matches[1]) {
      var paramsString = matches[1].replace(/^=|\"/g, ''),
          paramsSplit = paramsString.split(/\,\s*/);

      username = paramsSplit[0];

      paramsSplit.forEach(function(p,i) {
        if (i > 0) {
          var assignment = p.split(':');
          if (assignment[0] && assignment[1]) {
            params['data-' + esc(assignment[0])] = esc(assignment[1].trim());
          }
        }
      });
    }

    var avatarImg;
    if (options.lookupAvatarByPostNumber) {
      // client-side, we can retrieve the avatar from the post
      var postNumber = parseInt(params['data-post'], 10);
      avatarImg = options.lookupAvatarByPostNumber(postNumber);
    } else if (options.lookupAvatar) {
      // server-side, we need to lookup the avatar from the username
      avatarImg = options.lookupAvatar(username);
    }

    while (blockContents.length && (typeof blockContents[0] === "string" || blockContents[0] instanceof String)) {
      blockContents[0] = String(blockContents[0]).replace(/^\s+/, '');
      if (!blockContents[0].length) {
        blockContents.shift();
      } else {
        break;
      }
    }

    var contents = ['blockquote'];
    if (blockContents.length) {
      var self = this;

      var nextContents = blockContents.slice(1);
      blockContents = this.processBlock(blockContents[0], nextContents).concat(nextContents);

      blockContents.forEach(function (bc) {
        if (typeof bc === "string" || bc instanceof String) {
          var processed = self.processInline(String(bc));
          if (processed.length) {
            contents.push(['p'].concat(processed));
          }
        } else {
          contents.push(bc);
        }
      });
    }

    // If there's no username just return a simple quote
    if (!username) {
      return ['p', ['aside', params, contents]];
    }

    return ['aside', params,
               ['div', {'class': 'title'},
                 ['div', {'class': 'quote-controls'}],
                 avatarImg ? ['__RAW', avatarImg] : "",
                 username ? I18n.t('user.said', {username: username}) : ""
               ],
               contents
            ];
  }
});
