/*global Mousetrap:true */
import loadScript from 'discourse/lib/load-script';
import { default as computed, on, observes } from 'ember-addons/ember-computed-decorators';
import { showSelector } from "discourse/lib/emoji/emoji-toolbar";

// Our head can be a static string or a function that returns a string
// based on input (like for numbered lists).
function getHead(head, prev) {
  if (typeof head === "string") {
    return [head, head.length];
  } else {
    return getHead(head(prev));
  }
}

const _createCallbacks = [];

function Toolbar() {
  this.shortcuts = {};

  this.groups = [
    {group: 'fontStyles', buttons: []},
    {group: 'insertions', buttons: []},
    {group: 'extras', buttons: [], lastGroup: true}
  ];

  this.addButton({
    id: 'bold',
    group: 'fontStyles',
    shortcut: 'B',
    perform: e => e.applySurround('**', '**', 'bold_text')
  });

  this.addButton({
    id: 'italic',
    group: 'fontStyles',
    shortcut: 'I',
    perform: e => e.applySurround('*', '*', 'italic_text')
  });

  this.addButton({id: 'link', group: 'insertions', shortcut: 'K', action: 'showLinkModal'});

  this.addButton({
    id: 'quote',
    group: 'insertions',
    icon: 'quote-right',
    shortcut: 'Shift+9',
    perform: e => e.applySurround('> ', '', 'code_text')
  });

  this.addButton({
    id: 'code',
    group: 'insertions',
    shortcut: 'Shift+C',
    perform(e) {
      if (e.selected.value.indexOf("\n") !== -1) {
        e.applySurround('    ', '', 'code_text');
      } else {
        e.applySurround('`', '`', 'code_text');
      }
    },
  });

  this.addButton({
    id: 'bullet',
    group: 'extras',
    icon: 'list-ul',
    shortcut: 'Shift+8',
    title: 'composer.ulist_title',
    perform: e => e.applyList('* ', 'list_item')
  });

  this.addButton({
    id: 'list',
    group: 'extras',
    icon: 'list-ol',
    shortcut: 'Shift+7',
    title: 'composer.olist_title',
    perform: e => e.applyList(i => !i ? "1. " : `${parseInt(i) + 1}. `, 'list_item')
  });

  this.addButton({
    id: 'heading',
    group: 'extras',
    icon: 'font',
    shortcut: 'Alt+1',
    perform: e => e.applyList('## ', 'heading_text')
  });

  this.addButton({
    id: 'rule',
    group: 'extras',
    icon: 'minus',
    shortcut: 'Alt+R',
    title: 'composer.hr_title',
    perform: e => e.addText("\n\n----------\n")
  });
};

Toolbar.prototype.addButton = function(button) {
  const g = this.groups.findProperty('group', button.group);
  if (!g) {
    throw `Couldn't find toolbar group ${button.group}`;
  }

  const createdButton = {
    id: button.id,
    className: button.className || button.id,
    icon: button.icon || button.id,
    action: button.action || 'toolbarButton',
    perform: button.perform || Ember.K
  };

  if (button.sendAction) {
    createdButton.sendAction = button.sendAction;
  }

  const title = I18n.t(button.title || `composer.${button.id}_title`);
  if (button.shortcut) {
    const mac = /Mac|iPod|iPhone|iPad/.test(navigator.platform);
    const mod = mac ? 'Meta' : 'Ctrl';
    var shortcutTitle = `${mod}+${button.shortcut}`;

    // Mac users are used to glyphs for shortcut keys
    if (mac) {
      shortcutTitle = shortcutTitle
          .replace('Shift', "\u21E7")
          .replace('Meta', "\u2318")
          .replace('Alt', "\u2325")
          .replace(/\+/g, '');
    } else {
      shortcutTitle = shortcutTitle
          .replace('Shift', I18n.t('shortcut_modifier_key.shift'))
          .replace('Ctrl', I18n.t('shortcut_modifier_key.ctrl'))
          .replace('Alt', I18n.t('shortcut_modifier_key.alt'));
    }

    createdButton.title = `${title} (${shortcutTitle})`;

    this.shortcuts[`${mod}+${button.shortcut}`.toLowerCase()] = createdButton;
  } else {
    createdButton.title = title;
  }

  if (button.unshift) {
    g.buttons.unshift(createdButton);
  } else {
    g.buttons.push(createdButton);
  }
};

export function onToolbarCreate(func) {
  _createCallbacks.push(func);
};

export default Ember.Component.extend({
  classNames: ['d-editor'],
  ready: false,
  insertLinkHidden: true,
  link: '',
  lastSel: null,

  @computed('placeholder')
  placeholderTranslated(placeholder) {
    if (placeholder) return I18n.t(placeholder);
    return null;
  },

  @on('didInsertElement')
  _startUp() {
    this._applyEmojiAutocomplete();

    loadScript('defer/html-sanitizer-bundle').then(() => this.set('ready', true));

    const shortcuts = this.get('toolbar.shortcuts');
    Ember.keys(shortcuts).forEach(sc => {
      const button = shortcuts[sc];
      Mousetrap(this.$('.d-editor-input')[0]).bind(sc, () => {
        this.send(button.action, button);
        return false;
      });
    });

    // disable clicking on links in the preview
    this.$('.d-editor-preview').on('click.preview', e => {
      e.preventDefault();
      return false;
    });

    this.appEvents.on('composer:insert-text', text => {
      this._addText(this._getSelected(), text);
    });
  },

  @on('willDestroyElement')
  _shutDown() {
    this.appEvents.off('composer:insert-text');

    Ember.keys(this.get('toolbar.shortcuts')).forEach(sc => {
      Mousetrap(this.$('.d-editor-input')[0]).unbind(sc);
    });
    this.$('.d-editor-preview').off('click.preview');
  },

  @computed
  toolbar() {
    const toolbar = new Toolbar();
    _createCallbacks.forEach(cb => cb(toolbar));
    this.sendAction('extraButtons', toolbar);
    return toolbar;
  },

  _updatePreview() {
    const value = this.get('value');
    const markdownOptions = this.get('markdownOptions') || {};
    markdownOptions.sanitize = true;

    this.set('preview', Discourse.Dialect.cook(value || "", markdownOptions));
    Ember.run.scheduleOnce('afterRender', () => {
      if (this._state !== "inDOM") { return; }
      const $preview = this.$('.d-editor-preview');
      if ($preview.length === 0) return;

      this.sendAction('previewUpdated', $preview);
    });
  },

  @observes('ready', 'value')
  _watchForChanges() {
    if (!this.get('ready')) { return; }
    Ember.run.debounce(this, this._updatePreview, 30);
  },

  _applyEmojiAutocomplete() {
    if (!this.siteSettings.enable_emoji) { return; }

    const container = this.container;
    const template = container.lookup('template:emoji-selector-autocomplete.raw');
    const self = this;

    this.$('.d-editor-input').autocomplete({
      template: template,
      key: ":",

      transformComplete(v) {
        if (v.code) {
          return `${v.code}:`;
        } else {
          showSelector({
            appendTo: self.$(),
            container,
            onSelect: title => self._addText(self._getSelected(), `${title}:`)
          });
          return "";
        }
      },

      dataSource(term) {
        return new Ember.RSVP.Promise(resolve => {
          const full = `:${term}`;
          term = term.toLowerCase();

          if (term === "") {
            return resolve(["smile", "smiley", "wink", "sunny", "blush"]);
          }

          if (Discourse.Emoji.translations[full]) {
            return resolve([Discourse.Emoji.translations[full]]);
          }

          const options = Discourse.Emoji.search(term, {maxResults: 5});

          return resolve(options);
        }).then(list => list.map(code => {
          return {code, src: Discourse.Emoji.urlFor(code)};
        })).then(list => {
          if (list.length) {
            list.push({ label: I18n.t("composer.more_emoji") });
          }
          return list;
        });
      }
    });
  },

  _getSelected() {
    if (!this.get('ready')) { return; }

    const textarea = this.$('textarea.d-editor-input')[0];
    const start = textarea.selectionStart;
    const end = textarea.selectionEnd;

    const value = textarea.value.substring(start, end);
    const pre = textarea.value.slice(0, start);
    const post = textarea.value.slice(end);

    return { start, end, value, pre, post };
  },

  _selectText(from, length) {
    Ember.run.scheduleOnce('afterRender', () => {
      const textarea = this.$('textarea.d-editor-input')[0];
      textarea.selectionStart = from;
      textarea.selectionEnd = textarea.selectionStart + length;
    });
  },

  _applySurround(sel, head, tail, exampleKey) {
    const pre = sel.pre;
    const post = sel.post;

    const tlen = tail.length;
    if (sel.start === sel.end) {
      if (tlen === 0) { return; }

      const [hval, hlen] = getHead(head);
      const example = I18n.t(`composer.${exampleKey}`);
      this.set('value', `${pre}${hval}${example}${tail}${post}`);
      this._selectText(pre.length + hlen, example.length);
    } else {
      const lines = sel.value.split("\n");

      let [hval, hlen] = getHead(head);
      if (lines.length === 1 && pre.slice(-tlen) === tail && post.slice(0, hlen) === hval) {
        this.set('value', `${pre.slice(0, -hlen)}${sel.value}${post.slice(tlen)}`);
        this._selectText(sel.start - hlen, sel.value.length);
      } else {
        const contents = lines.map(l => {
          if (l.length === 0) { return l; }

          if (l.slice(0, hlen) === hval && tlen === 0 || l.slice(-tlen) === tail) {
            if (tlen === 0) {
              const result = l.slice(hlen);
              [hval, hlen] = getHead(head, hval);
              return result;
            } else if (l.slice(-tlen) === tail) {
              const result = l.slice(hlen, -tlen);
              [hval, hlen] = getHead(head, hval);
              return result;
            }
          }
          const result = `${hval}${l}${tail}`;
          [hval, hlen] = getHead(head, hval);
          return result;
        }).join("\n");

        this.set('value', `${pre}${contents}${post}`);
        if (lines.length === 1 && tlen > 0) {
          this._selectText(sel.start + hlen, contents.length - hlen - hlen);
        } else {
          this._selectText(sel.start, contents.length);
        }
      }
    }
  },

  _applyList(sel, head, exampleKey) {
    if (sel.value.indexOf("\n") !== -1) {
      this._applySurround(sel, head, '', exampleKey);
    } else {

      const [hval, hlen] = getHead(head);
      if (sel.start === sel.end) {
        sel.value = I18n.t(`composer.${exampleKey}`);
      }

      const trimmedPre = sel.pre.trim();
      const number = (sel.value.indexOf(hval) === 0) ? sel.value.slice(hlen) : `${hval}${sel.value}`;
      const preLines = trimmedPre.length ? `${trimmedPre}\n\n` : "";

      const trimmedPost = sel.post.trim();
      const post = trimmedPost.length ? `\n\n${trimmedPost}` : trimmedPost;

      this.set('value', `${preLines}${number}${post}`);
      this._selectText(preLines.length, number.length);
    }
  },

  _addText(sel, text) {
    const insert = `${sel.pre}${text}`;
    this.set('value', `${insert}${sel.post}`);
    this._selectText(insert.length, 0);
  },

  actions: {
    toolbarButton(button) {
      const selected = this._getSelected();
      const toolbarEvent = {
        selected,
        applySurround: (head, tail, exampleKey) => this._applySurround(selected, head, tail, exampleKey),
        applyList: (head, exampleKey) => this._applyList(selected, head, exampleKey),
        addText: text => this._addText(selected, text)
      };

      if (button.sendAction) {
        return this.sendAction(button.sendAction, toolbarEvent);
      } else {
        button.perform(toolbarEvent);
      }
    },

    showLinkModal() {
      this._lastSel = this._getSelected();
      this.set('insertLinkHidden', false);
    },

    insertLink() {
      const link = this.get('link');

      if (Ember.isEmpty(link)) { return; }
      const m = / "([^"]+)"/.exec(link);
      if (m && m.length === 2) {
        const description = m[1];
        const remaining = link.replace(m[0], '');
        this._addText(this._lastSel, `[${description}](${remaining})`);
      } else {
        const selectedValue = this._lastSel.value || link;
        this._addText(this._lastSel, `[${selectedValue}](${link})`);
      }

      this.set('link', '');
    },

    emoji() {
      showSelector({
        appendTo: this.$(),
        container: this.container,
        onSelect: title => this._addText(this._getSelected(), `:${title}:`)
      });
    }
  }

});
