import { avatarImg } from 'discourse/widgets/post';
import { dateNode } from 'discourse/helpers/node';
import RawHtml from 'discourse/widgets/raw-html';
import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import { iconNode } from 'discourse/helpers/fa-icon';

class Highlighted extends RawHtml {
  constructor(html, term) {
    super({ html: `<span>${html}</span>` });
    this.term = term;
  }

  decorate($html) {
    if (this.term) {
      $html.highlight(this.term.split(/\s+/), { className: 'search-highlight' });
    }
  }
}

function createSearchResult(type, linkField, fn) {
  return createWidget(`search-result-${type}`, {
    html(attrs) {
      return attrs.results.map(r => {
        return h('li', this.attach('link', {
          href: r.get(linkField),
          contents: () => fn.call(this, r, attrs.term),
          className: 'search-link'
        }));
      });
    }
  });
}

function postResult(result, link, term) {
  const html = [link];

  if (!this.site.mobileView) {
    html.push(h('span.blurb', [ dateNode(result.created_at),
                                ' - ',
                                new Highlighted(result.blurb, term) ]));
  }

  return html;
}

createSearchResult('user', 'path', function(u) {
  return [ avatarImg('small', { template: u.avatar_template, username: u.username }), ' ', u.username ];
});

createSearchResult('topic', 'url', function(result, term) {
  const topic = result.topic;
  const link = h('span.topic', [
    this.attach('topic-status', { topic, disableActions: true }),
    h('span.topic-title', new Highlighted(topic.get('fancyTitle'), term)),
    this.attach('category-link', { category: topic.get('category'), link: false })
  ]);

  return postResult.call(this, result, link, term);
});

createSearchResult('post', 'url', function(result, term) {
  return postResult.call(this, result, I18n.t('search.post_format', result), term);
});

createSearchResult('category', 'url', function (c) {
  return this.attach('category-link', { category: c, link: false });
});

createWidget('search-menu-results', {
  tagName: 'div.results',

  html(attrs) {
    if (attrs.noResults) {
      return h('div.no-results', I18n.t('search.no_results'));
    }

    const results = attrs.results;
    const resultTypes = results.resultTypes || [];
    return resultTypes.map(rt => {
      const more = [];

      const moreArgs = {
        className: 'filter',
        contents: () => [I18n.t('show_more'), ' ', iconNode('chevron-down')]
      };

      if (rt.moreUrl) {
        more.push(this.attach('link', $.extend(moreArgs, { href: rt.moreUrl })));
      } else if (rt.more) {
        more.push(this.attach('link', $.extend(moreArgs, { action: "moreOfType",
                                                           actionParam: rt.type,
                                                           className: "filter filter-type"})));
      }

      return [
        h('ul', this.attach(rt.componentName, { results: rt.results, term: attrs.term })),
        h('div.no-results', more)
      ];
    });
  }
});
