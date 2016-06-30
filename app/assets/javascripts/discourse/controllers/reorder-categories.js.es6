import { ajax } from 'discourse/lib/ajax';
import ModalFunctionality from 'discourse/mixins/modal-functionality';
const BufferedProxy = window.BufferedProxy; // import BufferedProxy from 'ember-buffered-proxy/proxy';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import { on, default as computed } from "ember-addons/ember-computed-decorators";
import Ember from 'ember';

const SortableArrayProxy = Ember.ArrayProxy.extend(Ember.SortableMixin);

export default Ember.Controller.extend(ModalFunctionality, Ember.Evented, {

  @on('init')
  _fixOrder() {
    this.send('fixIndices');
  },

  @computed("site.categories")
  categoriesBuffered(categories) {
    const bufProxy = Ember.ObjectProxy.extend(BufferedProxy);
    return categories.map(c => bufProxy.create({ content: c }));
  },

  categoriesOrdered: function() {
    return SortableArrayProxy.create({
      sortProperties: ['content.position'],
      content: this.get('categoriesBuffered')
    });
  }.property('categoriesBuffered'),

  showFixIndices: function() {
    const cats = this.get('categoriesOrdered');
    const len = cats.get('length');
    for (let i = 0; i < len; i++) {
      if (cats.objectAt(i).get('position') !== i) {
        return true;
      }
    }
    return false;
  }.property('categoriesOrdered.@each.position'),

  showApplyAll: function() {
    let anyChanged = false;
    this.get('categoriesBuffered').forEach(bc => { anyChanged = anyChanged || bc.get('hasBufferedChanges'); });
    return anyChanged;
  }.property('categoriesBuffered.@each.hasBufferedChanges'),

  saveDisabled: Ember.computed.or('showApplyAll', 'showFixIndices'),

  moveDir(cat, dir) {
    const cats = this.get('categoriesOrdered');
    const curIdx = cats.indexOf(cat);
    const desiredIdx = curIdx + dir;
    if (desiredIdx >= 0 && desiredIdx < cats.get('length')) {
      const curPos = cat.get('position');
      cat.set('position', curPos + dir);
      const otherCat = cats.objectAt(desiredIdx);
      otherCat.set('position', curPos - dir);
      this.send('commit');
    }
  },

  actions: {

    moveUp(cat) {
      this.moveDir(cat, -1);
    },
    moveDown(cat) {
      this.moveDir(cat, 1);
    },

    fixIndices() {
      const cats = this.get('categoriesOrdered');
      const len = cats.get('length');
      for (let i = 0; i < len; i++) {
        cats.objectAt(i).set('position', i);
      }
      this.send('commit');
    },

    commit() {
      this.get('categoriesBuffered').forEach(bc => {
        if (bc.get('hasBufferedChanges')) {
          bc.applyBufferedChanges();
        }
      });
      this.propertyDidChange('categoriesBuffered');
    },

    saveOrder() {
      const data = {};
      this.get('categoriesBuffered').forEach((cat) => {
        data[cat.get('id')] = cat.get('position');
      });
      ajax('/categories/reorder',
        {type: 'POST', data: {mapping: JSON.stringify(data)}}).
        then(() => this.send("closeModal")).
        catch(popupAjaxError);
    }
  }
});
