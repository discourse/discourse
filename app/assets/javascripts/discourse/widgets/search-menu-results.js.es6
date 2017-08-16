import { avatarImg } from 'discourse/widgets/post';
import { dateNode } from 'discourse/helpers/node';
import RawHtml from 'discourse/widgets/raw-html';
import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import { iconNode } from 'discourse-common/lib/icon-library';
import highlightText from 'discourse/lib/highlight-text';

class Highlighted extends RawHtml {
  constructor(html, term) {
    super({ html: `<span>${html}</span>` });
    this.term = term;
  }

  decorate($html) {
    highlightText($html, this.term);
  }
}

function createSearchResult({ type, linkField, builder }) {
  return createWidget(`search-result-${type}`, {
    html(attrs) {

      let i=-1;

      return attrs.results.map(r => {
        i+=1;
        let searchResultId;
        if (type === "topic") {
          searchResultId = r.get('topic_id');
        }
        let className = i === attrs.selected ? '.selected' : '';

        return h('li' + className, { attributes: { tabindex: '-1' } }, this.attach('link', {
          href: r.get(linkField),
          contents: () => builder.call(this, r, attrs.term),
          className: 'search-link',
          searchResultId,
          searchResultType: type,
          searchContextEnabled: attrs.searchContextEnabled,
          searchLogId: attrs.searchLogId
        }));
      });
    },
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

createSearchResult({
  type: 'user',
  linkField: 'path',
  builder(u) {
    return [ avatarImg('small', { template: u.avatar_template, username: u.username }), ' ', h('span.user-results', h('b', u.username)), ' ',  h('span.user-results', u.name ? u.name : '') ];
  }
});

createSearchResult({
  type: 'topic',
  linkField: 'url',
  builder(result, term) {
    const topic = result.topic;
    const link = h('span.topic', [
      this.attach('topic-status', { topic, disableActions: true }),
      h('span.topic-title', new Highlighted(topic.get('fancyTitle'), term)),
      this.attach('category-link', { category: topic.get('category'), link: false })
    ]);

    return postResult.call(this, result, link, term);
  }
});

createSearchResult({
  type: 'post',
  linkField: 'url',
  builder(result, term) {
    return postResult.call(this, result, I18n.t('search.post_format', result), term);
  }
});

createSearchResult({
  type: 'category',
  linkField: 'url',
  builder(c) {
    return this.attach('category-link', { category: c, link: false });
  }
});

createWidget('search-menu-results', {
  tagName: 'div.results',

  html(attrs) {
    if (attrs.invalidTerm) {
      return h('div.no-results', I18n.t('search.too_short'));
    }

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
        h('ul', this.attach(rt.componentName, {
          searchContextEnabled: attrs.searchContextEnabled,
          searchLogId: attrs.results.grouped_search_result.search_log_id,
          results: rt.results,
          term: attrs.term,
          selected: (attrs.selected && attrs.selected.type === rt.type) ? attrs.selected.index : -1
        })),
        h('div.no-results', more)
      ];
    });
  }
});
