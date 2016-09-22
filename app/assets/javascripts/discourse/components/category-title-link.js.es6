import computed from 'ember-addons/ember-computed-decorators';

export default Em.Component.extend({
  tagName: 'h3',

  @computed("category.name")
  categoryName(name) {
    return Handlebars.Utils.escapeExpression(name);
  }
});
