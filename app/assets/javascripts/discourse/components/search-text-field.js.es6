import computed from 'ember-addons/ember-computed-decorators';
import { on } from 'ember-addons/ember-computed-decorators';
import TextField from 'discourse/components/text-field';
import { findRawTemplate } from 'discourse/lib/raw-templates';
import { TAG_HASHTAG_POSTFIX } from 'discourse/lib/tag-hashtags';
import { SEPARATOR } from 'discourse/lib/category-hashtags';
import Category from 'discourse/models/category';
import { search as searchCategoryTag  } from 'discourse/lib/category-tag-search';
import userSearch from 'discourse/lib/user-search';

export default TextField.extend({
  @computed('searchService.searchContextEnabled')
  placeholder(searchContextEnabled) {
    return searchContextEnabled ? "" : I18n.t('search.title');
  },

  @on("didInsertElement")
  becomeFocused() {
    if (!this.get('hasAutofocus')) { return; }
    // iOS is crazy, without this we will not be
    // at the top of the page
    $(window).scrollTop(0);
    this.$().focus();
  },

  @on("didInsertElement")
  applyAutoComplete() {
    this._super();

    const $searchInput = this.$();
    this._applyCategoryHashtagAutocomplete($searchInput);
    this._applyUsernameAutocomplete($searchInput);
  },

  _applyCategoryHashtagAutocomplete($searchInput) {
    const siteSettings = this.siteSettings;

    $searchInput.autocomplete({
      template: findRawTemplate('category-tag-autocomplete'),
      key: '#',
      width: '100%',
      treatAsTextarea: true,
      transformComplete(obj) {
        if (obj.model) {
          return Category.slugFor(obj.model, SEPARATOR);
        } else {
          return `${obj.text}${TAG_HASHTAG_POSTFIX}`;
        }
      },
      dataSource(term) {
        return searchCategoryTag(term, siteSettings);
      }
    });
  },

  _applyUsernameAutocomplete($searchInput) {
    $searchInput.autocomplete({
      template: findRawTemplate('user-selector-autocomplete'),
      dataSource: term => userSearch({ term, undefined, includeGroups: true }),
      key: "@",
      width: '100%',
      treatAsTextarea: true,
      transformComplete: v => v.username || v.name
    });
  }
});
