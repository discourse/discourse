import ModalFunctionality from 'discourse/mixins/modal-functionality';
const BufferedProxy = window.BufferedProxy; // import BufferedProxy from 'ember-buffered-proxy/proxy';
import binarySearch from 'discourse/lib/binary-search';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import computed from "ember-addons/ember-computed-decorators";
import Ember from 'ember';

export default Ember.Controller.extend(ModalFunctionality, Ember.Evented, {

  @computed("site.categories")
  categoriesBuffered(categories) {
    const bufProxy = Ember.ObjectProxy.extend(BufferedProxy);
    return categories.map(c => bufProxy.create({ content: c }));
  },

  // uses propertyDidChange()
  @computed('categoriesBuffered')
  categoriesGrouped(cats) {
    const map = {};
    cats.forEach((cat) => {
      const p = cat.get('position') || 0;
      if (!map[p]) {
        map[p] = {pos: p, cats: [cat]};
      } else {
        map[p].cats.push(cat);
      }
    });
    const result = [];
    Object.keys(map).map(p => parseInt(p)).sort((a,b) => a-b).forEach(function(pos) {
      result.push(map[pos]);
    });
    return result;
  },

  showApplyAll: function() {
    let anyChanged = false;
    this.get('categoriesBuffered').forEach(bc => { anyChanged = anyChanged || bc.get('hasBufferedChanges') });
    return anyChanged;
  }.property('categoriesBuffered.@each.hasBufferedChanges'),

  saveDisabled: Ember.computed.alias('showApplyAll'),

  moveDir(cat, dir) {
    const grouped = this.get('categoriesGrouped'),
      curPos = cat.get('position'),
      curGroupIdx = binarySearch(grouped, curPos, "pos"),
      curGroup = grouped[curGroupIdx];

    if (curGroup.cats.length === 1 && ((dir === -1 && curGroupIdx !== 0) || (dir === 1 && curGroupIdx !== (grouped.length - 1)))) {
      const nextGroup = grouped[curGroupIdx + dir],
        nextPos = nextGroup.pos;
      cat.set('position', nextPos);
    } else {
      cat.set('position', curPos + dir);
    }
    cat.applyBufferedChanges();
    Ember.run.next(this, () => {
      this.propertyDidChange('categoriesGrouped');
      Ember.run.schedule('afterRender', this, () => {
        this.set('scrollIntoViewId', cat.get('id'));
        this.trigger('scrollIntoView');
      });
    });
  },

  actions: {

    moveUp(cat) {
      this.moveDir(cat, -1);
    },
    moveDown(cat) {
      this.moveDir(cat, 1);
    },

    commit() {
      this.get('categoriesBuffered').forEach(bc => {
        if (bc.get('hasBufferedChanges')) {
          bc.applyBufferedChanges();
        }
      });
      this.propertyDidChange('categoriesGrouped');
    },

    saveOrder() {
      const data = {};
      this.get('categoriesBuffered').forEach((cat) => {
        data[cat.get('id')] = cat.get('position');
      });
      Discourse.ajax('/categories/reorder',
        {type: 'POST', data: {mapping: JSON.stringify(data)}}).
        then(() => this.send("closeModal")).
        catch(popupAjaxError);
    }
  }
});
