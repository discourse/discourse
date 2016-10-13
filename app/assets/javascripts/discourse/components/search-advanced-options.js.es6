import { on, observes, default as computed } from 'ember-addons/ember-computed-decorators';

const REGEXP_FILTER_PREFIXES   = /\s?(user:|@|category:|#|group:|badge:|tags?:|in:|status:|posts_count:|(before|after):)/ig;

const REGEXP_USERNAME_PREFIX   = /\s?(user:|@)/ig;
const REGEXP_CATEGORY_PREFIX   = /\s?(category:|#)/ig;
const REGEXP_GROUP_PREFIX      = /\s?group:/ig;
const REGEXP_BADGE_PREFIX      = /\s?badge:/ig;
const REGEXP_TAGS_PREFIX       = /\s?tags?:/ig;
const REGEXP_IN_PREFIX         = /\s?in:/ig;
const REGEXP_STATUS_PREFIX     = /\s?status:/ig;
const REGEXP_POST_COUNT_PREFIX = /\s?posts_count:/ig;
const REGEXP_POST_TIME_PREFIX  = /\s?(before|after):/ig;

const REGEXP_CATEGORY_SLUG  = /\s?(\#[a-zA-Z0-9\-:]+)/ig;
const REGEXP_CATEGORY_ID    = /\s?(category:[0-9]+)/ig;
const REGEXP_POST_TIME_WHEN = /(before|after)/ig;

export default Em.Component.extend({
  tagName: 'div',
  classNames: ['search-advanced', 'row'],
  searchedTerms: {username: [], category: null, group: [], badge: [], tags: [],
    in: '', status: '', posts_count: '', time: {when: 'before', days: ''}},
  inOptions: [
    {name: I18n.t('search.advanced.filters.likes'),     value: "likes"},
    {name: I18n.t('search.advanced.filters.posted'),    value: "posted"},
    {name: I18n.t('search.advanced.filters.watching'),  value: "watching"},
    {name: I18n.t('search.advanced.filters.tracking'),  value: "tracking"},
    {name: I18n.t('search.advanced.filters.private'),   value: "private"},
    {name: I18n.t('search.advanced.filters.bookmarks'), value: "bookmarks"},
    {name: I18n.t('search.advanced.filters.first'),     value: "first"},
    {name: I18n.t('search.advanced.filters.pinned'),    value: "pinned"},
    {name: I18n.t('search.advanced.filters.unpinned'),  value: "unpinned"},
    {name: I18n.t('search.advanced.filters.wiki'),      value: "wiki"}
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

  @on('init')
  @observes('searchTerm')
  _init() {
    let searchTerm = this.get('searchTerm');

    if (!searchTerm)
      return;

    this.findUsername(searchTerm);
    this.findCategory(searchTerm);
    this.findGroup(searchTerm);
    this.findBadge(searchTerm);
    this.findTags(searchTerm);
    this.findIn(searchTerm);
    this.findStatus(searchTerm);
    this.findPostsCount(searchTerm);
    this.findPostTime(searchTerm);
  },

  findSearchTerm(EXPRESSION, searchTerm) {
    if (!searchTerm)
      return "";

    const expression_location = searchTerm.search(EXPRESSION);
    if (expression_location === -1)
      return "";

    const remaining_phrase = searchTerm.substring(expression_location + 2);
    let next_expression_location = remaining_phrase.search(REGEXP_FILTER_PREFIXES);
    if (next_expression_location === -1)
      next_expression_location = remaining_phrase.length;

    return searchTerm.substring(expression_location, next_expression_location + expression_location + 2);
  },

  findUsername(searchTerm) {
    const match = this.findSearchTerm(REGEXP_USERNAME_PREFIX, searchTerm);
    if (match.length !== 0) {
      let existingInput = _.isArray(this.get('searchedTerms.username')) ? this.get('searchedTerms.username')[0] : this.get('searchedTerms.username');
      let userInput = match.replace(REGEXP_USERNAME_PREFIX, '');
      if (userInput.length !== 0 && existingInput !== userInput)
        this.set('searchedTerms.username', [userInput]);
    } else
      this.set('searchedTerms.username', []);
  },

  @observes('searchedTerms.username')
  updateUsername() {
    let searchTerm = this.get('searchTerm');

    const match = this.findSearchTerm(REGEXP_USERNAME_PREFIX, searchTerm);
    const userFilter = this.get('searchedTerms.username');
    if (userFilter && userFilter.length !== 0)
      if (match.length !== 0)
        searchTerm = searchTerm.replace(match, ` @${userFilter}`);
      else
        searchTerm += ` @${userFilter}`;
    else if (match.length !== 0)
      searchTerm = searchTerm.replace(match, '');

    this.set('searchTerm', searchTerm);
  },

  findCategory(searchTerm) {
    const match = this.findSearchTerm(REGEXP_CATEGORY_PREFIX, searchTerm);
    if (match.length !== 0) {
      let existingInput = _.isArray(this.get('searchedTerms.category')) ? this.get('searchedTerms.category')[0] : this.get('searchedTerms.category');
      const subcategories = match.replace(REGEXP_CATEGORY_PREFIX, '').split(':');
      if (subcategories.length > 1) {
        let userInput = Discourse.Category.findBySlug(subcategories[1], subcategories[0]);
        if ((!existingInput && userInput)
          || (existingInput && userInput && existingInput.id !== userInput.id))
          this.set('searchedTerms.category', userInput.id);
      } else
        if (isNaN(subcategories)) {
          let userInput = Discourse.Category.findSingleBySlug(subcategories[0]);
          if ((!existingInput && userInput)
            || (existingInput && userInput && existingInput.id !== userInput.id))
            this.set('searchedTerms.category', userInput.id);
        } else {
          let userInput = Discourse.Category.findById(subcategories[0]);
          if ((!existingInput && userInput)
            || (existingInput && userInput && existingInput.id !== userInput.id))
            this.set('searchedTerms.category', userInput.id);
        }
    } else
      this.set('searchedTerms.category', null);
  },

  @observes('searchedTerms.category')
  updateCategory() {
    let searchTerm = this.get('searchTerm');
    const categoryFilter = Discourse.Category.findById(this.get('searchedTerms.category'));

    const match = this.findSearchTerm(REGEXP_CATEGORY_PREFIX, searchTerm);
    const slugCategoryMatches = match.match(REGEXP_CATEGORY_SLUG);
    const idCategoryMatches = match.match(REGEXP_CATEGORY_ID);
    if (categoryFilter && categoryFilter.length !== 0) {
      const id = categoryFilter.id;
      const slug = categoryFilter.slug;
      if (categoryFilter && categoryFilter.parentCategory) {
        const parentSlug = categoryFilter.parentCategory.slug;
        if (slugCategoryMatches)
          searchTerm = searchTerm.replace(slugCategoryMatches[0], ` #${parentSlug}:${slug}`);
        else if (idCategoryMatches)
          searchTerm = searchTerm.replace(idCategoryMatches[0], ` category:${id}`);
        else
          searchTerm += ` #${parentSlug}:${slug}`;
      } else if (categoryFilter) {
        if (slugCategoryMatches)
          searchTerm = searchTerm.replace(slugCategoryMatches[0], ` #${slug}`);
        else if (idCategoryMatches)
          searchTerm = searchTerm.replace(idCategoryMatches[0], ` category:${id}`);
        else
          searchTerm += ` #${slug}`;
      }
    } else {
      if (slugCategoryMatches)
        searchTerm = searchTerm.replace(slugCategoryMatches[0], '');
      if (idCategoryMatches)
        searchTerm = searchTerm.replace(idCategoryMatches[0], '');
    }

    this.set('searchTerm', searchTerm);
  },

  findGroup(searchTerm) {
    const match = this.findSearchTerm(REGEXP_GROUP_PREFIX, searchTerm);
    if (match.length !== 0) {
      let existingInput = _.isArray(this.get('searchedTerms.group')) ? this.get('searchedTerms.group')[0] : this.get('searchedTerms.group');
      let userInput = match.replace(REGEXP_GROUP_PREFIX, '');
      if (userInput.length !== 0 && existingInput !== userInput)
        this.set('searchedTerms.group', [userInput]);
    } else
      this.set('searchedTerms.group', []);
  },

  @observes('searchedTerms.group')
  updateGroup() {
    let searchTerm = this.get('searchTerm');

    const match = this.findSearchTerm(REGEXP_GROUP_PREFIX, searchTerm);
    const groupFilter = this.get('searchedTerms.group');
    if (groupFilter && groupFilter.length !== 0)
      if (match.length !== 0)
        searchTerm = searchTerm.replace(match, ` group:${groupFilter}`);
      else
        searchTerm += ` group:${groupFilter}`;
    else if (match.length !== 0)
      searchTerm = searchTerm.replace(match, '');

    this.set('searchTerm', searchTerm);
  },

  findBadge(searchTerm) {
    const match = this.findSearchTerm(REGEXP_BADGE_PREFIX, searchTerm);
    if (match.length !== 0) {
      let existingInput = _.isArray(this.get('searchedTerms.badge')) ? this.get('searchedTerms.badge')[0] : this.get('searchedTerms.badge');
      let userInput = match.replace(REGEXP_BADGE_PREFIX, '');
      if (userInput.length !== 0 && existingInput !== userInput)
        this.set('searchedTerms.badge', [match.replace(REGEXP_BADGE_PREFIX, '')]);
    } else
      this.set('searchedTerms.badge', []);
  },

  @observes('searchedTerms.badge')
  updateBadge() {
    let searchTerm = this.get('searchTerm');

    const match = this.findSearchTerm(REGEXP_BADGE_PREFIX, searchTerm);
    const badgeFilter = this.get('searchedTerms.badge');
    if (badgeFilter && badgeFilter.length !== 0)
      if (match.length !== 0)
        searchTerm = searchTerm.replace(match, ` badge:${badgeFilter}`);
      else
        searchTerm += ` badge:${badgeFilter}`;
    else if (match.length !== 0)
      searchTerm = searchTerm.replace(match, '');

    this.set('searchTerm', searchTerm);
  },

  findTags(searchTerm) {
    const match = this.findSearchTerm(REGEXP_TAGS_PREFIX, searchTerm);
    if (match.length !== 0) {
      let existingInput = _.isArray(this.get('searchedTerms.tags')) ? this.get('searchedTerms.tags').join(',') : this.get('searchedTerms.tags');
      let userInput = match.replace(REGEXP_TAGS_PREFIX, '');
      if (userInput.length !== 0 && existingInput !== userInput)
        this.set('searchedTerms.tags', userInput.split(','));
    } else
      this.set('searchedTerms.tags', []);
  },

  @observes('searchedTerms.tags')
  updateTags() {
    let searchTerm = this.get('searchTerm');

    const match = this.findSearchTerm(REGEXP_TAGS_PREFIX, searchTerm);
    const tagFilter = this.get('searchedTerms.tags');
    if (tagFilter && tagFilter.length !== 0) {
      const tags = tagFilter.join(',');
      if (match.length !== 0)
        searchTerm = searchTerm.replace(match, ` tags:${tags}`);
      else
        searchTerm += ` tags:${tags}`;
    } else if (match.length !== 0)
      searchTerm = searchTerm.replace(match, '');

    this.set('searchTerm', searchTerm);
  },

  findIn(searchTerm) {
    const match = this.findSearchTerm(REGEXP_IN_PREFIX, searchTerm);
    if (match.length !== 0) {
      let existingInput = this.get('searchedTerms.in');
      let userInput = match.replace(REGEXP_IN_PREFIX, '');
      if (userInput.length !== 0 && existingInput !== userInput)
        this.set('searchedTerms.in', userInput);
    } else
      this.set('searchedTerms.in', '');
  },

  @observes('searchedTerms.in')
  updateIn() {
    let searchTerm = this.get('searchTerm');

    const match = this.findSearchTerm(REGEXP_IN_PREFIX, searchTerm);
    const inFilter = this.get('searchedTerms.in');
    if (inFilter)
      if (match.length !== 0)
        searchTerm = searchTerm.replace(match, ` in:${inFilter}`);
      else
        searchTerm += ` in:${inFilter}`;
    else if (match.length !== 0)
      searchTerm = searchTerm.replace(match, '');

    this.set('searchTerm', searchTerm);
  },

  findStatus(searchTerm) {
    const match = this.findSearchTerm(REGEXP_STATUS_PREFIX, searchTerm);
    if (match.length !== 0) {
      let existingInput = this.get('searchedTerms.status');
      let userInput = match.replace(REGEXP_STATUS_PREFIX, '');
      if (userInput.length !== 0 && existingInput !== userInput)
        this.set('searchedTerms.status', userInput);
    } else
      this.set('searchedTerms.status', '');
  },

  @observes('searchedTerms.status')
  updateStatus() {
    let searchTerm = this.get('searchTerm');

    const match = this.findSearchTerm(REGEXP_STATUS_PREFIX, searchTerm);
    const statusFilter = this.get('searchedTerms.status');
    if (statusFilter)
      if (match.length !== 0)
        searchTerm = searchTerm.replace(match, ` status:${statusFilter}`);
      else
        searchTerm += ` status:${statusFilter}`;
    else if (match.length !== 0)
      searchTerm = searchTerm.replace(match, '');

    this.set('searchTerm', searchTerm);
  },

  findPostsCount(searchTerm) {
    const match = this.findSearchTerm(REGEXP_POST_COUNT_PREFIX, searchTerm);
    if (match.length !== 0) {
      let existingInput = this.get('searchedTerms.posts_count');
      let userInput = match.replace(REGEXP_POST_COUNT_PREFIX, '');
      if (userInput.length !== 0 && existingInput !== userInput)
        this.set('searchedTerms.posts_count', userInput);
    } else
      this.set('searchedTerms.posts_count', '');
  },

  @observes('searchedTerms.posts_count')
  updatePostsCount() {
    let searchTerm = this.get('searchTerm');

    const match = this.findSearchTerm(REGEXP_POST_COUNT_PREFIX, searchTerm);
    const postsCountFilter = this.get('searchedTerms.posts_count');
    if (postsCountFilter)
      if (match.length !== 0)
        searchTerm = searchTerm.replace(match, ` posts_count:${postsCountFilter}`);
      else
        searchTerm += ` posts_count:${postsCountFilter}`;
    else if (match.length !== 0)
      searchTerm = searchTerm.replace(match, '');

    this.set('searchTerm', searchTerm);
  },

  findPostTime(searchTerm) {
    const match = this.findSearchTerm(REGEXP_POST_TIME_WHEN, searchTerm);
    if (match.length !== 0) {
      let existingInputWhen = this.get('searchedTerms.time.when');
      let userInputWhen = match.match(REGEXP_POST_TIME_WHEN)[0];
      if (userInputWhen.length !== 0 && existingInputWhen !== userInputWhen)
        this.set('searchedTerms.time.when', userInputWhen);

      let existingInputDays = this.get('searchedTerms.time.days');
      let userInputDays = match.replace(REGEXP_POST_TIME_PREFIX, '');
      if (userInputDays.length !== 0 && existingInputDays !== userInputDays)
        this.set('searchedTerms.time.days', userInputDays);
    } else
      this.set('searchedTerms.time.days', '');
  },

  @observes('searchedTerms.time.when', 'searchedTerms.time.days')
  updatePostTime() {
    let searchTerm = this.get('searchTerm');

    const match = this.findSearchTerm(REGEXP_POST_TIME_PREFIX, searchTerm);
    const timeDaysFilter = this.get('searchedTerms.time.days');
    if (timeDaysFilter) {
      const when = this.get('searchedTerms.time.when');
      if (match.length !== 0)
        searchTerm = searchTerm.replace(match, ` ${when}:${timeDaysFilter}`);
      else
        searchTerm += ` ${when}:${timeDaysFilter}`;
    } else if (match.length !== 0)
      searchTerm = searchTerm.replace(match, '');

    this.set('searchTerm', searchTerm);
  },

  groupFinder(term) {
    const Group = require('discourse/models/group').default;
    return Group.findAll({search: term, ignore_automatic: false});
  },

  badgeFinder(term) {
    const Badge = require('discourse/models/badge').default;
    return Badge.findAll({search: term});
  },

  @computed('isExpanded')
  collapsedClassName(isExpanded) {
    return isExpanded ? "fa-caret-down" : "fa-caret-right";
  },

  actions: {
    expandOptions() {
      this.set('isExpanded', !this.get('isExpanded'));
      if (this.get('isExpanded'))
        this._init();
    }
  }
});
