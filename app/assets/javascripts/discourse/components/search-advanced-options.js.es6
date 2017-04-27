import { observes } from 'ember-addons/ember-computed-decorators';
import { escapeExpression } from 'discourse/lib/utilities';

const REGEXP_BLOCKS                = /(([^" \t\n\x0B\f\r]+)?(("[^"]+")?))/g;

const REGEXP_USERNAME_PREFIX       = /^(user:|@)/ig;
const REGEXP_CATEGORY_PREFIX       = /^(category:|#)/ig;
const REGEXP_GROUP_PREFIX          = /^group:/ig;
const REGEXP_BADGE_PREFIX          = /^badge:/ig;
const REGEXP_TAGS_PREFIX           = /^(tags?:|#(?=[a-z0-9\-]+::tag))/ig;
const REGEXP_IN_PREFIX             = /^in:/ig;
const REGEXP_STATUS_PREFIX         = /^status:/ig;
const REGEXP_MIN_POST_COUNT_PREFIX = /^min_post_count:/ig;
const REGEXP_POST_TIME_PREFIX      = /^(before|after):/ig;
const REGEXP_TAGS_REPLACE          = /(^(tags?:|#(?=[a-z0-9\-]+::tag))|::tag\s?$)/ig;

const REGEXP_IN_MATCH                 = /^in:(posted|watching|tracking|bookmarks|first|pinned|unpinned|wiki|unseen)/ig;
const REGEXP_SPECIAL_IN_LIKES_MATCH   = /^in:likes/ig;
const REGEXP_SPECIAL_IN_PRIVATE_MATCH = /^in:private/ig;
const REGEXP_SPECIAL_IN_SEEN_MATCH    = /^in:seen/ig;

const REGEXP_CATEGORY_SLUG            = /^(\#[a-zA-Z0-9\-:]+)/ig;
const REGEXP_CATEGORY_ID              = /^(category:[0-9]+)/ig;
const REGEXP_POST_TIME_WHEN           = /^(before|after)/ig;

export default Em.Component.extend({
  classNames: ['search-advanced-options'],

  inOptions: [
    {name: I18n.t('search.advanced.filters.unseen'),  value: "unseen"},
    {name: I18n.t('search.advanced.filters.posted'),    value: "posted"},
    {name: I18n.t('search.advanced.filters.watching'),  value: "watching"},
    {name: I18n.t('search.advanced.filters.tracking'),  value: "tracking"},
    {name: I18n.t('search.advanced.filters.bookmarks'), value: "bookmarks"},
    {name: I18n.t('search.advanced.filters.first'),     value: "first"},
    {name: I18n.t('search.advanced.filters.pinned'),    value: "pinned"},
    {name: I18n.t('search.advanced.filters.unpinned'),  value: "unpinned"},
    {name: I18n.t('search.advanced.filters.wiki'),  value: "wiki"},
  ],
  statusOptions: [
    {name: I18n.t('search.advanced.statuses.open'),        value: "open"},
    {name: I18n.t('search.advanced.statuses.closed'),      value: "closed"},
    {name: I18n.t('search.advanced.statuses.archived'),    value: "archived"},
    {name: I18n.t('search.advanced.statuses.noreplies'),   value: "noreplies"},
    {name: I18n.t('search.advanced.statuses.single_user'), value: "single_user"},
  ],
  postTimeOptions: [
    {name: I18n.t('search.advanced.post.time.before'),  value: "before"},
    {name: I18n.t('search.advanced.post.time.after'),   value: "after"}
  ],

  init() {
    this._super();
    this._init();
    Ember.run.scheduleOnce('afterRender', () => {
      this._update();
    });
  },

  @observes('searchTerm')
  _updateOptions() {
    this._update();
    Ember.run.debounce(this, this._update, 250);
  },

  _init() {
    this.setProperties({
      searchedTerms: {
        username: '',
        category: '',
        group: [],
        badge: [],
        tags: [],
        in: '',
        special: {
          in: {
            likes: false,
            private: false,
            seen: false
          }
        },
        status: '',
        min_post_count: '',
        time: {
          when: 'before',
          days: ''
        }
      }
    });
  },

  _update() {
    if (!this.get('searchTerm')) {
      this._init();
      return;
    }

    this.setSearchedTermValue('searchedTerms.username', REGEXP_USERNAME_PREFIX);
    this.setSearchedTermValueForCategory();
    this.setSearchedTermValueForGroup();
    this.setSearchedTermValueForBadge();
    this.setSearchedTermValueForTags();
    this.setSearchedTermValue('searchedTerms.in', REGEXP_IN_PREFIX, REGEXP_IN_MATCH);
    this.setSearchedTermSpecialInValue('searchedTerms.special.in.likes', REGEXP_SPECIAL_IN_LIKES_MATCH);
    this.setSearchedTermSpecialInValue('searchedTerms.special.in.private', REGEXP_SPECIAL_IN_PRIVATE_MATCH);
    this.setSearchedTermSpecialInValue('searchedTerms.special.in.seen', REGEXP_SPECIAL_IN_SEEN_MATCH);
    this.setSearchedTermValue('searchedTerms.status', REGEXP_STATUS_PREFIX);
    this.setSearchedTermValueForPostTime();
    this.setSearchedTermValue('searchedTerms.min_post_count', REGEXP_MIN_POST_COUNT_PREFIX);
  },

  findSearchTerms() {
    const searchTerm = escapeExpression(this.get('searchTerm'));
    if (!searchTerm)
      return [];

    const blocks = searchTerm.match(REGEXP_BLOCKS);
    if (!blocks) return [];

    let result = [];
    blocks.forEach(block => {
      if (block.length !== 0)
        result.push(block);
    });

    return result;
  },

  filterBlocks(regexPrefix) {
    const blocks = this.findSearchTerms();
    if (!blocks) return [];

    let result = [];
    blocks.forEach(block => {
      if (block.search(regexPrefix) !== -1)
        result.push(block);
    });

    return result;
  },

  setSearchedTermValue(key, replaceRegEx, matchRegEx = null) {
    matchRegEx = matchRegEx || replaceRegEx;
    const match = this.filterBlocks(matchRegEx);

    let val = this.get(key);

    if (match.length !== 0) {
      const userInput = match[0].replace(replaceRegEx, '');
      if (val !== userInput) {
        this.set(key, userInput);
      }
    } else if(val && val.length !== 0) {
      this.set(key, '');
    }
  },

  setSearchedTermSpecialInValue(key, replaceRegEx) {
    const match = this.filterBlocks(replaceRegEx);

    if (match.length !== 0) {
      if (this.get(key) !== true) {
        this.set(key, true);
      }
    } else if(this.get(key) !== false) {
      this.set(key, false);
    }
  },

  setSearchedTermValueForCategory() {
    const match = this.filterBlocks(REGEXP_CATEGORY_PREFIX);
    if (match.length !== 0) {
      const existingInput = this.get('searchedTerms.category');
      const subcategories = match[0].replace(REGEXP_CATEGORY_PREFIX, '').split(':');
      if (subcategories.length > 1) {
        const userInput = Discourse.Category.findBySlug(subcategories[1], subcategories[0]);
        if ((!existingInput && userInput)
          || (existingInput && userInput && existingInput.id !== userInput.id))
          this.set('searchedTerms.category', [userInput]);
      } else
      if (isNaN(subcategories)) {
        const userInput = Discourse.Category.findSingleBySlug(subcategories[0]);
        if ((!existingInput && userInput)
          || (existingInput && userInput && existingInput.id !== userInput.id))
          this.set('searchedTerms.category', [userInput]);
      } else {
        const userInput = Discourse.Category.findById(subcategories[0]);
        if ((!existingInput && userInput)
          || (existingInput && userInput && existingInput.id !== userInput.id))
          this.set('searchedTerms.category', [userInput]);
      }
    } else
      this.set('searchedTerms.category', '');
  },

  setSearchedTermValueForGroup() {
    const match = this.filterBlocks(REGEXP_GROUP_PREFIX);
    const group = this.get('searchedTerms.group');

    if (match.length !== 0) {
      const existingInput = _.isArray(group) ? group[0] : group;
      const userInput = match[0].replace(REGEXP_GROUP_PREFIX, '');

      if (existingInput !== userInput) {
        this.set('searchedTerms.group', (userInput.length !== 0) ? [userInput] : []);
      }
    } else if (group.length !== 0) {
      this.set('searchedTerms.group', []);
    }
  },

  setSearchedTermValueForBadge() {
    const match = this.filterBlocks(REGEXP_BADGE_PREFIX);
    const badge = this.get('searchedTerms.badge');

    if (match.length !== 0) {
      const existingInput = _.isArray(badge) ? badge[0] : badge;
      const userInput = match[0].replace(REGEXP_BADGE_PREFIX, '');

      if (existingInput !== userInput) {
        this.set('searchedTerms.badge', (userInput.length !== 0) ? [userInput] : []);
      }
    } else if (badge.length !== 0) {
      this.set('searchedTerms.badge', []);
    }
  },

  setSearchedTermValueForTags() {
    if (!this.siteSettings.tagging_enabled) return;

    const match = this.filterBlocks(REGEXP_TAGS_PREFIX);
    const tags = this.get('searchedTerms.tags');

    if (match.length !== 0) {
      const existingInput = _.isArray(tags) ? tags.join(',') : tags;
      const userInput = match[0].replace(REGEXP_TAGS_REPLACE, '');

      if (existingInput !== userInput) {
        this.set('searchedTerms.tags', (userInput.length !== 0) ? userInput.split(',') : []);
      }
    } else if (tags.length !== 0) {
      this.set('searchedTerms.tags', []);
    }
  },

  setSearchedTermValueForPostTime() {
    const match = this.filterBlocks(REGEXP_POST_TIME_PREFIX);

    if (match.length !== 0) {
      const existingInputWhen = this.get('searchedTerms.time.when');
      const userInputWhen = match[0].match(REGEXP_POST_TIME_WHEN)[0];
      const existingInputDays = this.get('searchedTerms.time.days');
      const userInputDays = match[0].replace(REGEXP_POST_TIME_PREFIX, '');

      if (existingInputWhen !== userInputWhen) {
        this.set('searchedTerms.time.when', userInputWhen);
      }

      if (existingInputDays !== userInputDays) {
        this.set('searchedTerms.time.days', userInputDays);
      }
    } else {
      this.set('searchedTerms.time.days', '');
    }
  },

  @observes('searchedTerms.username')
  updateSearchTermForUsername() {
    const match = this.filterBlocks(REGEXP_USERNAME_PREFIX);
    const userFilter = this.get('searchedTerms.username');
    let searchTerm = this.get('searchTerm') || '';

    if (userFilter && userFilter.length !== 0) {
      if (match.length !== 0) {
        searchTerm = searchTerm.replace(match[0], `@${userFilter}`);
      } else {
        searchTerm += ` @${userFilter}`;
      }

      this.set('searchTerm', searchTerm.trim());
    } else if (match.length !== 0) {
      searchTerm = searchTerm.replace(match[0], '');
      this.set('searchTerm', searchTerm.trim());
    }
  },

  @observes('searchedTerms.category')
  updateSearchTermForCategory() {
    const match = this.filterBlocks(REGEXP_CATEGORY_PREFIX);
    const categoryFilter = this.get('searchedTerms.category');
    let searchTerm = this.get('searchTerm') || '';

    const slugCategoryMatches = (match.length !== 0) ? match[0].match(REGEXP_CATEGORY_SLUG) : null;
    const idCategoryMatches = (match.length !== 0) ? match[0].match(REGEXP_CATEGORY_ID) : null;
    if (categoryFilter && categoryFilter[0]) {
      const id = categoryFilter[0].id;
      const slug = categoryFilter[0].slug;
      if (categoryFilter[0].parentCategory) {
        const parentSlug = categoryFilter[0].parentCategory.slug;
        if (slugCategoryMatches)
          searchTerm = searchTerm.replace(slugCategoryMatches[0], `#${parentSlug}:${slug}`);
        else if (idCategoryMatches)
          searchTerm = searchTerm.replace(idCategoryMatches[0], `category:${id}`);
        else
          searchTerm += ` #${parentSlug}:${slug}`;

        this.set('searchTerm', searchTerm.trim());
      } else {
        if (slugCategoryMatches)
          searchTerm = searchTerm.replace(slugCategoryMatches[0], `#${slug}`);
        else if (idCategoryMatches)
          searchTerm = searchTerm.replace(idCategoryMatches[0], `category:${id}`);
        else
          searchTerm += ` #${slug}`;

        this.set('searchTerm', searchTerm.trim());
      }
    } else {
      if (slugCategoryMatches)
        searchTerm = searchTerm.replace(slugCategoryMatches[0], '');
      if (idCategoryMatches)
        searchTerm = searchTerm.replace(idCategoryMatches[0], '');

      this.set('searchTerm', searchTerm.trim());
    }
  },

  @observes('searchedTerms.group')
  updateSearchTermForGroup() {
    const match = this.filterBlocks(REGEXP_GROUP_PREFIX);
    const groupFilter = this.get('searchedTerms.group');
    let searchTerm = this.get('searchTerm') || '';

    if (groupFilter && groupFilter.length !== 0) {
      if (match.length !== 0) {
        searchTerm = searchTerm.replace(match[0], ` group:${groupFilter}`);
      } else {
        searchTerm += ` group:${groupFilter}`;
      }

      this.set('searchTerm', searchTerm);
    } else if (match.length !== 0) {
      searchTerm = searchTerm.replace(match[0], '');
      this.set('searchTerm', searchTerm.trim());
    }
  },

  @observes('searchedTerms.badge')
  updateSearchTermForBadge() {
    const match = this.filterBlocks(REGEXP_BADGE_PREFIX);
    const badgeFilter = this.get('searchedTerms.badge');
    let searchTerm = this.get('searchTerm') || '';

    if (badgeFilter && badgeFilter.length !== 0) {
      if (match.length !== 0) {
        searchTerm = searchTerm.replace(match[0], ` badge:${badgeFilter}`);
      } else {
        searchTerm += ` badge:${badgeFilter}`;
      }

      this.set('searchTerm', searchTerm);
    } else if (match.length !== 0) {
      searchTerm = searchTerm.replace(match[0], '');
      this.set('searchTerm', searchTerm.trim());
    }
  },

  @observes('searchedTerms.tags')
  updateSearchTermForTags() {
    const match = this.filterBlocks(REGEXP_TAGS_PREFIX);
    const tagFilter = this.get('searchedTerms.tags');
    let searchTerm = this.get('searchTerm') || '';

    if (tagFilter && tagFilter.length !== 0) {
      const tags = tagFilter.join(',');

      if (match.length !== 0) {
        searchTerm = searchTerm.replace(match[0], `tags:${tags}`);
      } else {
        searchTerm += ` tags:${tags}`;
      }

      this.set('searchTerm', searchTerm.trim());
    } else if (match.length !== 0) {
      searchTerm = searchTerm.replace(match[0], '');
      this.set('searchTerm', searchTerm.trim());
    }
  },

  @observes('searchedTerms.in')
  updateSearchTermForIn() {
    const match = this.filterBlocks(REGEXP_IN_MATCH);
    const inFilter = this.get('searchedTerms.in');
    let searchTerm = this.get('searchTerm') || '';

    if (inFilter) {
      if (match.length !== 0) {
        searchTerm = searchTerm.replace(match[0], `in:${inFilter}`);
      } else {
        searchTerm += ` in:${inFilter}`;
      }

      this.set('searchTerm', searchTerm.trim());
    } else if (match.length !== 0) {
      searchTerm = searchTerm.replace(match, '');
      this.set('searchTerm', searchTerm.trim());
    }
  },

  @observes('searchedTerms.special.in.likes')
  updateSearchTermForSpecialInLikes() {
    const match = this.filterBlocks(REGEXP_SPECIAL_IN_LIKES_MATCH);
    const inFilter = this.get('searchedTerms.special.in.likes');
    let searchTerm = this.get('searchTerm') || '';

    if (inFilter) {
      if (match.length === 0) {
        searchTerm += ` in:likes`;
        this.set('searchTerm', searchTerm.trim());
      }
    } else if (match.length !== 0) {
      searchTerm = searchTerm.replace(match, '');
      this.set('searchTerm', searchTerm.trim());
    }
  },

  @observes('searchedTerms.special.in.private')
  updateSearchTermForSpecialInPrivate() {
    const match = this.filterBlocks(REGEXP_SPECIAL_IN_PRIVATE_MATCH);
    const inFilter = this.get('searchedTerms.special.in.private');
    let searchTerm = this.get('searchTerm') || '';

    if (inFilter) {
      if (match.length === 0) {
        searchTerm += ` in:private`;
        this.set('searchTerm', searchTerm.trim());
      }
    } else if (match.length !== 0) {
      searchTerm = searchTerm.replace(match, '');
      this.set('searchTerm', searchTerm.trim());
    }
  },

  @observes('searchedTerms.special.in.seen')
  updateSearchTermForSpecialInSeen() {
    const match = this.filterBlocks(REGEXP_SPECIAL_IN_SEEN_MATCH);
    const inFilter = this.get('searchedTerms.special.in.seen');
    let searchTerm = this.get('searchTerm') || '';

    if (inFilter) {
      if (match.length === 0) {
        searchTerm += ` in:seen`;
        this.set('searchTerm', searchTerm.trim());
      }
    } else if (match.length !== 0) {
      searchTerm = searchTerm.replace(match, '');
      this.set('searchTerm', searchTerm.trim());
    }
  },

  @observes('searchedTerms.status')
  updateSearchTermForStatus() {
    const match = this.filterBlocks(REGEXP_STATUS_PREFIX);
    const statusFilter = this.get('searchedTerms.status');
    let searchTerm = this.get('searchTerm') || '';

    if (statusFilter) {
      if (match.length !== 0) {
        searchTerm = searchTerm.replace(match[0], `status:${statusFilter}`);
      } else {
        searchTerm += ` status:${statusFilter}`;
      }

      this.set('searchTerm', searchTerm.trim());
    } else if (match.length !== 0) {
      searchTerm = searchTerm.replace(match[0], '');
      this.set('searchTerm', searchTerm.trim());
    }
  },

  @observes('searchedTerms.time.when', 'searchedTerms.time.days')
  updateSearchTermForPostTime() {
    const match = this.filterBlocks(REGEXP_POST_TIME_PREFIX);
    const timeDaysFilter = this.get('searchedTerms.time.days');
    let searchTerm = this.get('searchTerm') || '';

    if (timeDaysFilter) {
      const when = this.get('searchedTerms.time.when');
      if (match.length !== 0) {
        searchTerm = searchTerm.replace(match[0], `${when}:${timeDaysFilter}`);
      } else {
        searchTerm += ` ${when}:${timeDaysFilter}`;
      }

      this.set('searchTerm', searchTerm.trim());
    } else if (match.length !== 0) {
      searchTerm = searchTerm.replace(match[0], '');
      this.set('searchTerm', searchTerm.trim());
    }
  },

  @observes('searchedTerms.min_post_count')
  updateSearchTermForMinPostCount() {
    const match = this.filterBlocks(REGEXP_MIN_POST_COUNT_PREFIX);
    const postsCountFilter = this.get('searchedTerms.min_post_count');
    let searchTerm = this.get('searchTerm') || '';

    if (postsCountFilter) {
      if (match.length !== 0) {
        searchTerm = searchTerm.replace(match[0], `min_post_count:${postsCountFilter}`);
      } else {
        searchTerm += ` min_post_count:${postsCountFilter}`;
      }

      this.set('searchTerm', searchTerm.trim());
    } else if (match.length !== 0) {
      searchTerm = searchTerm.replace(match[0], '');
      this.set('searchTerm', searchTerm.trim());
    }
  },

  groupFinder(term) {
    const Group = require('discourse/models/group').default;
    return Group.findAll({search: term, ignore_automatic: false});
  },

  badgeFinder(term) {
    const Badge = require('discourse/models/badge').default;
    return Badge.findAll({search: term});
  }
});
