import { default as computed } from "ember-addons/ember-computed-decorators";
import PreferencesTabController from "discourse/mixins/preferences-tab-controller";
import { setting } from 'discourse/lib/computed';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import { cook } from 'discourse/lib/text';

export default Ember.Controller.extend(PreferencesTabController, {

  saveAttrNames: [
    'name',
    'bio_raw',
    'website',
    'location',
    'custom_fields',
    'user_fields',
    'profile_background',
    'card_background',
    'date_of_birth'
  ],

  canEditName: setting('enable_names'),

  newNameInput: null,

  @computed()
  nameInstructions() {
    return I18n.t(this.siteSettings.full_name_required ? 'user.name.instructions_required' : 'user.name.instructions');
  },

  @computed("model.has_title_badges")
  canSelectTitle(hasTitleBadges) {
    return this.siteSettings.enable_badges && hasTitleBadges;
  },

  @computed("model.user_fields.@each.value")
  userFields() {
    let siteUserFields = this.site.get('user_fields');
    if (!Ember.isEmpty(siteUserFields)) {
      const userFields = this.get('model.user_fields');

      // Staff can edit fields that are not `editable`
      if (!this.get('currentUser.staff')) {
        siteUserFields = siteUserFields.filterBy('editable', true);
      }
      return siteUserFields.sortBy('position').map(function(field) {
        const value = userFields ? userFields[field.get('id').toString()] : null;
        return Ember.Object.create({ value, field });
      });
    }
  },

  @computed("model.can_change_bio")
  canChangeBio(canChangeBio)
  {
    return canChangeBio;
  },

  actions: {

    save() {
      this.set('saved', false);

      const model = this.get('model'),
            userFields = this.get('userFields');

      model.set('name', this.get('newNameInput'));

      // Update the user fields
      if (!Ember.isEmpty(userFields)) {
        const modelFields = model.get('user_fields');
        if (!Ember.isEmpty(modelFields)) {
          userFields.forEach(function(uf) {
            modelFields[uf.get('field.id').toString()] = uf.get('value');
          });
        }
      }

      return model.save(this.get('saveAttrNames')).then(() => {
        model.set('bio_cooked', cook(model.get('bio_raw')));
        this.set('saved', true);
      }).catch(popupAjaxError);
    }
  }
});
