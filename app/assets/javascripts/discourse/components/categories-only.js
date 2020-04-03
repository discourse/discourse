import Component from "@ember/component";
import computed from 'ember-addons/ember-computed-decorators';

export default Component.extend({
  tagName: "",

  @computed
  noCategoryStyle() {
    return this.siteSettings.category_style === 'none';
  }
});
