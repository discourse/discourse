/*global Mousetrap:true */
import { default as computed, on, observes } from 'ember-addons/ember-computed-decorators';
import { showSelector } from "discourse/lib/emoji/toolbar";
import Category from 'discourse/models/category';
import { categoryHashtagTriggerRule } from 'discourse/lib/category-hashtags';
import { TAG_HASHTAG_POSTFIX } from 'discourse/lib/tag-hashtags';
import { search as searchCategoryTag  } from 'discourse/lib/category-tag-search';
import { SEPARATOR } from 'discourse/lib/category-hashtags';
import { cook } from 'discourse/lib/text';
import { translations } from 'pretty-text/emoji/data';
import { emojiSearch } from 'pretty-text/emoji';
import { emojiUrlFor } from 'discourse/lib/text';
import { getRegister } from 'discourse-common/lib/get-owner';
import { findRawTemplate } from 'discourse/lib/raw-templates';
import { determinePostReplaceSelection } from 'discourse/lib/utilities';
import deprecated from 'discourse-common/lib/deprecated';

// Our head can be a static string or a function that returns a string
// based on input (like for numbered lists).
function getHead(head, prev) {
  if (typeof head === "string") {
    return [head, head.length];
  } else {
    return getHead(head(prev));
  }
}

function getButtonLabel(labelKey, defaultLabel) {
  // use the Font Awesome icon if the label matches the default
  return I18n.t(labelKey) === defaultLabel ? null : labelKey;
}

const OP = {
  NONE: 0,
  REMOVED: 1,
  ADDED: 2
};

const FOUR_SPACES_INDENT = '4-spaces-indent';

const _createCallbacks = [];

class Toolbar {

  constructor(site) {
    this.shortcuts = {};

    this.groups = [
      {group: 'fontStyles', buttons: []},
      {group: 'insertions', buttons: []},
      {group: 'extras', buttons: []}
    ];

    this.addButton({
      trimLeading: true,
      id: 'bold',
      group: 'fontStyles',
      icon: 'bold',
      label: getButtonLabel('composer.bold_label', 'B'),
      shortcut: 'B',
      perform: e => e.applySurround('**', '**', 'bold_text')
    });

    this.addButton({
      trimLeading: true,
      id: 'italic',
      group: 'fontStyles',
      icon: 'italic',
      label: getButtonLabel('composer.italic_label', 'I'),
      shortcut: 'I',
      perform: e => e.applySurround('_', '_', 'italic_text')
    });

    this.addButton({id: 'link', group: 'insertions', shortcut: 'K', action: 'showLinkModal'});

    this.addButton({
      id: 'quote',
      group: 'insertions',
      icon: 'quote-right',
      shortcut: 'Shift+9',
      perform: e => e.applySurround('> ', '', 'code_text')
    });

    this.addButton({id: 'code', group: 'insertions', shortcut: 'Shift+C', action: 'formatCode'});

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
      icon: 'header',
      label: getButtonLabel('composer.heading_label', 'H'),
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

    if (site.mobileView) {
      this.groups.push({group: 'mobileExtras', buttons: []});
    }

    this.groups[this.groups.length-1].lastGroup = true;
  }

  addButton(button) {
    const g = this.groups.findBy('group', button.group);
    if (!g) {
      throw `Couldn't find toolbar group ${button.group}`;
    }

    const createdButton = {
      id: button.id,
      className: button.className || button.id,
      label: button.label,
      icon: button.label ? null : button.icon || button.id,
      action: button.action || 'toolbarButton',
      perform: button.perform || Ember.K,
      trimLeading: button.trimLeading
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
  }
}

export function addToolbarCallback(func) {
  _createCallbacks.push(func);
}

export function onToolbarCreate(func) {
  deprecated('`onToolbarCreate` is deprecated, use the plugin api instead.');
  addToolbarCallback(func);
};

export default Ember.Component.extend({
  classNames: ['d-editor'],
  ready: false,
  insertLinkHidden: true,
  linkUrl: '',
  linkText: '',
  lastSel: null,
  _mouseTrap: null,

  @computed('placeholder')
  placeholderTranslated(placeholder) {
    if (placeholder) return I18n.t(placeholder);
    return null;
  },

  _readyNow() {
    this.set('ready', true);

    if (this.get('autofocus')) {
      this.$('textarea').focus();
    }
  },

  init() {
    this._super();
    this.register = getRegister(this);
  },

  didInsertElement() {
    this._super();

    const $editorInput = this.$('.d-editor-input');

    this._applyEmojiAutocomplete($editorInput);
    this._applyCategoryHashtagAutocomplete($editorInput);

    Ember.run.scheduleOnce('afterRender', this, this._readyNow);

    const mouseTrap = Mousetrap(this.$('.d-editor-input')[0]);
    const shortcuts = this.get('toolbar.shortcuts');
    Object.keys(shortcuts).forEach(sc => {
      const button = shortcuts[sc];
      mouseTrap.bind(sc, () => {
        this.send(button.action, button);
        return false;
      });
    });

    // disable clicking on links in the preview
    this.$('.d-editor-preview').on('click.preview', e => {
      if ($(e.target).is("a")) {
        e.preventDefault();
        return false;
      }
    });

    this.appEvents.on('composer:insert-text', text => this._addText(this._getSelected(), text));
    this.appEvents.on('composer:replace-text', (oldVal, newVal) => this._replaceText(oldVal, newVal));
    this._mouseTrap = mouseTrap;
  },

  @on('willDestroyElement')
  _shutDown() {
    this.appEvents.off('composer:insert-text');
    this.appEvents.off('composer:replace-text');

    const mouseTrap = this._mouseTrap;
    Object.keys(this.get('toolbar.shortcuts')).forEach(sc => mouseTrap.unbind(sc));
    this.$('.d-editor-preview').off('click.preview');
  },

  @computed
  toolbar() {
    const toolbar = new Toolbar(this.site);
    _createCallbacks.forEach(cb => cb(toolbar));
    this.sendAction('extraButtons', toolbar);
    return toolbar;
  },

  _updatePreview() {
    if (this._state !== "inDOM") { return; }

    const value = this.get('value');
    const markdownOptions = this.get('markdownOptions') || {};

    markdownOptions.siteSettings = this.siteSettings;

    this.set('preview', cook(value));
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

    // Debouncing in test mode is complicated
    if (Ember.testing) {
      this._updatePreview();
    } else {
      Ember.run.debounce(this, this._updatePreview, 30);
    }
  },

  _applyCategoryHashtagAutocomplete() {
    const siteSettings = this.siteSettings;

    this.$('.d-editor-input').autocomplete({
      template: findRawTemplate('category-tag-autocomplete'),
      key: '#',
      transformComplete(obj) {
        if (obj.model) {
          return Category.slugFor(obj.model, SEPARATOR);
        } else {
          return `${obj.text}${TAG_HASHTAG_POSTFIX}`;
        }
      },
      dataSource(term) {
        return searchCategoryTag(term, siteSettings);
      },
      triggerRule(textarea, opts) {
        return categoryHashtagTriggerRule(textarea, opts);
      }
    });
  },

  _applyEmojiAutocomplete($editorInput) {
    if (!this.siteSettings.enable_emoji) { return; }

    const register = this.register;
    const self = this;

    $editorInput.autocomplete({
      template: findRawTemplate('emoji-selector-autocomplete'),
      key: ":",
      afterComplete(text) {
        self.set('value', text);
      },

      transformComplete(v) {
        if (v.code) {
          return `${v.code}:`;
        } else {
          showSelector({
            appendTo: self.$(),
            register,
            onSelect: title => {
              // Remove the previously type characters when a new emoji is selected from the selector.
              let selected = self._getSelected();
              let newPre = selected.pre.replace(/:[^:]+$/, ":");
              let numOfRemovedChars = selected.pre.length - newPre.length;
              selected.pre = newPre;
              selected.start -= numOfRemovedChars;
              selected.end -= numOfRemovedChars;
              self._addText(selected, `${title}:`);
            }
          });
          return "";
        }
      },

      dataSource(term) {
        return new Ember.RSVP.Promise(resolve => {
          const full = `:${term}`;
          term = term.toLowerCase();

          if (term === "") {
            return resolve(["slight_smile", "smile", "wink", "sunny", "blush"]);
          }

          if (translations[full]) {
            return resolve([translations[full]]);
          }

          const options = emojiSearch(term, {maxResults: 5});

          return resolve(options);
        }).then(list => list.map(code => {
          return {code, src: emojiUrlFor(code)};
        })).then(list => {
          if (list.length) {
            list.push({ label: I18n.t("composer.more_emoji") });
          }
          return list;
        });
      }
    });
  },

  _getSelected(trimLeading, opts) {
    if (!this.get('ready')) { return; }

    const textarea = this.$('textarea.d-editor-input')[0];
    const value = textarea.value;
    let start = textarea.selectionStart;
    let end = textarea.selectionEnd;

    // trim trailing spaces cause **test ** would be invalid
    while (end > start && /\s/.test(value.charAt(end-1))) {
      end--;
    }

    if (trimLeading) {
      // trim leading spaces cause ** test** would be invalid
      while(end > start && /\s/.test(value.charAt(start))) {
        start++;
      }
    }

    const selVal = value.substring(start, end);
    const pre = value.slice(0, start);
    const post = value.slice(end);

    if (opts && opts.lineVal) {
      const lineVal = value.split("\n")[value.substr(0, textarea.selectionStart).split("\n").length - 1];
      return { start, end, value: selVal, pre, post, lineVal };
    } else {
      return { start, end, value: selVal, pre, post };
    }
  },

  _selectText(from, length) {
    Ember.run.scheduleOnce('afterRender', () => {
      const $textarea = this.$('textarea.d-editor-input');
      const textarea = $textarea[0];
      const oldScrollPos = $textarea.scrollTop();
      if (!this.capabilities.isIOS) {
        $textarea.focus();
      }
      textarea.selectionStart = from;
      textarea.selectionEnd = textarea.selectionStart + length;
      $textarea.scrollTop(oldScrollPos);
    });
  },

  // perform the same operation over many lines of text
  _getMultilineContents(lines, head, hval, hlen, tail, tlen) {
    let operation = OP.NONE;

    return lines.map(l => {
      if (l.length === 0) { return l; }

      if (operation !== OP.ADDED &&
          (l.slice(0, hlen) === hval && tlen === 0 || l.slice(-tlen) === tail)) {
        operation = OP.REMOVED;
        if (tlen === 0) {
          const result = l.slice(hlen);
          [hval, hlen] = getHead(head, hval);
          return result;
        } else if (l.slice(-tlen) === tail) {
          const result = l.slice(hlen, -tlen);
          [hval, hlen] = getHead(head, hval);
          return result;
        }
      } else if (operation === OP.NONE) {
        operation = OP.ADDED;
      } else if (operation === OP.REMOVED) {
        return l;
      }

      const result = `${hval}${l}${tail}`;
      [hval, hlen] = getHead(head, hval);
      return result;
    }).join("\n");
  },

  _applySurround(sel, head, tail, exampleKey, opts) {
    const pre = sel.pre;
    const post = sel.post;

    const tlen = tail.length;
    if (sel.start === sel.end) {
      if (tlen === 0) { return; }

      const [hval, hlen] = getHead(head);
      const example = I18n.t(`composer.${exampleKey}`);
      this.set('value', `${pre}${hval}${example}${tail}${post}`);
      this._selectText(pre.length + hlen, example.length);
    } else if (opts && !opts.multiline) {
      const [hval, hlen] = getHead(head);

      if (pre.slice(-hlen) === hval && post.slice(0, tail.length) === tail) {
        this.set('value', `${pre.slice(0, -hlen)}${sel.value}${post.slice(tail.length)}`);
        this._selectText(sel.start - hlen, sel.value.length);
      } else {
        this.set('value', `${pre}${hval}${sel.value}${tail}${post}`);
        this._selectText(sel.start + hlen, sel.value.length);
      }
    } else {
      const lines = sel.value.split("\n");

      let [hval, hlen] = getHead(head);
      if (lines.length === 1 && pre.slice(-tlen) === tail && post.slice(0, hlen) === hval) {
        this.set('value', `${pre.slice(0, -hlen)}${sel.value}${post.slice(tlen)}`);
        this._selectText(sel.start - hlen, sel.value.length);
      } else {
        const contents = this._getMultilineContents(lines, head, hval, hlen, tail, tlen);

        this.set('value', `${pre}${contents}${post}`);
        if (lines.length === 1 && tlen > 0) {
          this._selectText(sel.start + hlen, sel.value.length);
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

  _replaceText(oldVal, newVal) {
    const val = this.get('value');
    const needleStart = val.indexOf(oldVal);

    if (needleStart === -1) {
      // Nothing to replace.
      return;
    }

    const textarea = this.$('textarea.d-editor-input')[0];

    // Determine post-replace selection.
    const newSelection = determinePostReplaceSelection({
      selection: { start: textarea.selectionStart, end: textarea.selectionEnd },
      needle: { start: needleStart, end: needleStart + oldVal.length },
      replacement: { start: needleStart, end: needleStart + newVal.length }
    });

    // Replace value (side effect: cursor at the end).
    this.set('value', val.replace(oldVal, newVal));

    // Restore cursor.
    this._selectText(newSelection.start, newSelection.end - newSelection.start);
  },

  _addText(sel, text) {
    const $textarea = this.$('textarea.d-editor-input');
    const insert = `${sel.pre}${text}`;
    const value = `${insert}${sel.post}`;
    this.set('value', value);
    $textarea.val(value);
    $textarea.prop("selectionStart", insert.length);
    $textarea.prop("selectionEnd", insert.length);
    Ember.run.scheduleOnce("afterRender", () => $textarea.focus());
  },

  actions: {
    toolbarButton(button) {
      const selected = this._getSelected(button.trimLeading);
      const toolbarEvent = {
        selected,
        selectText: (from, length) => this._selectText(from, length),
        applySurround: (head, tail, exampleKey, opts) => this._applySurround(selected, head, tail, exampleKey, opts),
        applyList: (head, exampleKey) => this._applyList(selected, head, exampleKey),
        addText: text => this._addText(selected, text),
        replaceText: text => this._addText({pre: '', post: ''}, text),
        getText: () => this.get('value'),
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

    formatCode() {
      const sel = this._getSelected('', { lineVal: true });
      const selValue = sel.value;
      const hasNewLine = selValue.indexOf("\n") !== -1;
      const isBlankLine = sel.lineVal.trim().length === 0;
      const isFourSpacesIndent = this.siteSettings.code_formatting_style === FOUR_SPACES_INDENT;

      if (!hasNewLine) {
        if (selValue.length === 0 && isBlankLine) {
          if (isFourSpacesIndent) {
            const example = I18n.t(`composer.code_text`);
            this.set('value', `${sel.pre}    ${example}${sel.post}`);
            return this._selectText(sel.pre.length + 4, example.length);
          } else {
            return this._applySurround(sel, "```\n", "\n```", 'paste_code_text');
          }
        } else {
          return this._applySurround(sel, '`', '`', 'code_title');
        }
      } else {
        if (isFourSpacesIndent) {
          return this._applySurround(sel, '    ', '', 'code_text');
        } else {
          const preNewline = (sel.pre[-1] !== "\n" && sel.pre !== "") ? "\n" : "";
          const postNewline = sel.post[0] !== "\n" ? "\n" : "";
          return this._addText(sel, `${preNewline}\`\`\`\n${sel.value}\n\`\`\`${postNewline}`);
        }
      }
    },

    insertLink() {
      const origLink = this.get('linkUrl');
      const linkUrl = (origLink.indexOf('://') === -1) ? `http://${origLink}` : origLink;
      const sel = this._lastSel;

      if (Ember.isEmpty(linkUrl)) { return; }

      const linkText = this.get('linkText') || '';
      if (linkText.length) {
        this._addText(sel, `[${linkText}](${linkUrl})`);
      } else {
        if (sel.value) {
          this._addText(sel, `[${sel.value}](${linkUrl})`);
        } else {
          this._addText(sel, `[${origLink}](${linkUrl})`);
          this._selectText(sel.start + 1, origLink.length);
        }
      }

      this.set('linkUrl', '');
      this.set('linkText', '');
    },

    emoji() {
      showSelector({
        appendTo: this.$(),
        register: this.register,
        onSelect: title => this._addText(this._getSelected(), `:${title}:`)
      });
    }
  }
});
