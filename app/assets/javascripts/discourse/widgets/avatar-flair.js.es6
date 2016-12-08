import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';

createWidget('avatar-flair', {
  tagName: 'div.avatar-flair',

  isIcon(attrs) {
    return (attrs.primary_group_flair_url && attrs.primary_group_flair_url.substr(0,3) === 'fa-');
  },

  title(attrs) {
    return attrs.primary_group_name;
  },

  buildClasses(attrs) {
    return 'avatar-flair-' + attrs.primary_group_name + (attrs.primary_group_flair_bg_color ? ' rounded' : '');
  },

  buildAttributes(attrs) {
    var style = '';
    if (!this.isIcon(attrs)) {
      style += 'background-image: url(' + Handlebars.Utils.escapeExpression(attrs.primary_group_flair_url) + '); ';
    }
    if (attrs.primary_group_flair_bg_color) {
      style += 'background-color: #' + Handlebars.Utils.escapeExpression(attrs.primary_group_flair_bg_color) + '; ';
    }
    if (attrs.primary_group_flair_color) {
      style += 'color: #' + Handlebars.Utils.escapeExpression(attrs.primary_group_flair_color) + '; ';
    }
    return {style: style};
  },

  html(attrs) {
    if (this.isIcon(attrs)) {
      return [h('i', { className: 'fa ' + attrs.primary_group_flair_url })];
    } else {
      return [];
    }
  }
});
