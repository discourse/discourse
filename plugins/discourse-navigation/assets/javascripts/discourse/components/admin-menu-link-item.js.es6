import MenuLink from 'discourse/plugins/navigation/discourse/models/menu-link';
import { bufferedProperty } from 'discourse/mixins/buffered-content';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import { propertyEqual } from 'discourse/lib/computed';

export default Ember.Component.extend(bufferedProperty('menuLink'), {
  editing: Ember.computed.empty('menuLink.id'),
  classNameBindings: [':menu-link'],

  cantMoveUp: propertyEqual('menuLink', 'firstField'),
  cantMoveDown: propertyEqual('menuLink', 'lastField'),

  flags: function() {
    const ret = [];
    if (this.get('menuLink.visible_main')) {
      ret.push(I18n.t('admin.menu_links.enabled.main'));
    }
    if (this.get('menuLink.visible_hamburger_general')) {
      ret.push(I18n.t('admin.menu_links.enabled.hamburger.general'));
    }
    if (this.get('menuLink.visible_hamburger_footer')) {
      ret.push(I18n.t('admin.menu_links.enabled.hamburger.footer'));
    }
    if (this.get('menuLink.visible_brand_general')) {
      ret.push(I18n.t('admin.menu_links.enabled.branding.general'));
    }
    if (this.get('menuLink.visible_brand_icon')) {
      ret.push(I18n.t('admin.menu_links.enabled.branding.icon'));
    }

    return ret.join(', ');
  }.property('menuLink.visible_main', 'menuLink.visible_hamburger_general', 'menuLink.visible_hamburger_footer', 'menuLink.visible_brand_general', 'menuLink.visible_brand_icon'),

  actions: {
    save() {
      const self = this;
      const buffered = this.get('buffered');
      const attrs = buffered.getProperties('name',
                                           'icon',
                                           'url',
                                           'visible_main',
                                           'visible_hamburger_general',
                                           'visible_hamburger_footer',
                                           'visible_brand_general',
                                           'visible_brand_icon');

      this.get('menuLink').save(attrs).then(function() {
        self.set('editing', false);
        self.commitBuffer();
      }).catch(popupAjaxError);
    },

    moveUp() {
      this.sendAction('moveUpAction', this.get('menuLink'));
    },

    moveDown() {
      this.sendAction('moveDownAction', this.get('menuLink'));
    },

    edit() {
      this.set('editing', true);
    },

    destroy() {
      this.sendAction('destroyAction', this.get('menuLink'));
    },

    cancel() {
      const id = this.get('menuLink.id');
      if (Ember.isEmpty(id)) {
        this.sendAction('destroyAction', this.get('menuLink'));
      } else {
        this.rollbackBuffer();
        this.set('editing', false);
      }
    }
  }
});
