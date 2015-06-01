import DiscourseContainerView from 'discourse/views/container';

export default DiscourseContainerView.extend({
  classNames: 'colors-container',

  _createButtons: function() {
    var colors = this.get('colors'),
        isUsed, usedColors = this.get('usedColors') || [];

    if (!colors) return;

    var self = this;
    colors.forEach(function(color) {
      isUsed = usedColors.indexOf(color.toUpperCase()) >= 0;

      self.attachViewWithArgs({
        tagName: 'button',
        attributeBindings: ['style', 'title'],
        classNames: ['colorpicker'].concat( isUsed ? ['used-color'] : ['unused-color'] ),
        style: ('background-color: #' + color + ';').htmlSafe(),
        title: isUsed ? I18n.t("category.already_used") : null,
        click: function() {
          self.set("value", color);
          return false;
        }
      });

    });
  }.on('init')
});
