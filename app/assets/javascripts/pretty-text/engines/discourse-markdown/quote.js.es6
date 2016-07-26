import { register } from 'pretty-text/engines/discourse-markdown/bbcode';

export function setup(helper) {
  register(helper, 'quote', {noWrap: true, singlePara: true}, (contents, bbParams, options) => {
    const params = {'class': 'quote'};
    let username = null;

    if (bbParams) {
      const paramsSplit = bbParams.split(/\,\s*/);
      username = paramsSplit[0];

      paramsSplit.forEach(function(p,i) {
        if (i > 0) {
          var assignment = p.split(':');
          if (assignment[0] && assignment[1]) {
            const escaped = helper.escape(assignment[0]);
            // don't escape attributes, makes no sense
            if (escaped === assignment[0]) {
              params['data-' + assignment[0]] = helper.escape(assignment[1].trim());
            }
          }
        }
      });
    }

    let avatarImg;
    const postNumber = parseInt(params['data-post'], 10);
    const topicId = parseInt(params['data-topic'], 10);

    if (options.lookupAvatarByPostNumber) {
      // client-side, we can retrieve the avatar from the post
      avatarImg = options.lookupAvatarByPostNumber(postNumber, topicId);
    } else if (options.lookupAvatar) {
      // server-side, we need to lookup the avatar from the username
      avatarImg = options.lookupAvatar(username);
    }

    // If there's no username just return a simple quote
    if (!username) {
      return ['p', ['aside', params, ['blockquote'].concat(contents)]];
    }

    const header = ['div', {'class': 'title'},
                    ['div', {'class': 'quote-controls'}],
                    avatarImg ? ['__RAW', avatarImg] : "",
                    username ? `${username}:` : "" ];

    if (options.topicId && postNumber && options.getTopicInfo && topicId !== options.topicId) {
      const topicInfo = options.getTopicInfo(topicId);
      if (topicInfo) {
        var href = topicInfo.href;
        if (postNumber > 0) { href += "/" + postNumber; }
        // get rid of username said stuff
        header.pop();
        header.push(['a', {'href': href}, topicInfo.title]);
      }
    }

    return ['aside', params, header, ['blockquote'].concat(contents)];
  });
}
