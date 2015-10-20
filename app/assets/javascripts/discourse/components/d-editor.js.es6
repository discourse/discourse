import loadScript from 'discourse/lib/load-script';
import { default as property, on } from 'ember-addons/ember-computed-decorators';
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

export default Ember.Component.extend({
  classNames: ['d-editor'],
  ready: false,
  insertLinkHidden: true,
  link: '',
  lastSel: null,

  @on('didInsertElement')
  _loadSanitizer() {
    this._applyEmojiAutocomplete();
    loadScript('defer/html-sanitizer-bundle').then(() => this.set('ready', true));
  },

  @property('ready', 'value')
  preview(ready, value) {
    if (!ready) { return; }

    const text = Discourse.Dialect.cook(value || "", {sanitize: true});
    return text ? text : "";
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
            onSelect: title => self._addText(`${title}:`)
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
    let start = textarea.selectionStart;
    let end = textarea.selectionEnd;

    if (start === end) {
      start = end = textarea.value.length;
    }

    const value = textarea.value.substring(start, end);
    const pre = textarea.value.slice(0, start);
    const post = textarea.value.slice(end);

    return { start, end, value, pre, post };
  },

  _selectText(from, length) {
    Ember.run.scheduleOnce('afterRender', () => {
      const textarea = this.$('textarea.d-editor-input')[0];
      textarea.focus();
      textarea.selectionStart = from;
      textarea.selectionEnd = textarea.selectionStart + length;
    });
  },

  _applySurround(head, tail, exampleKey) {
    const sel = this._getSelected();
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

  _applyList(head, exampleKey) {
    const sel = this._getSelected();
    if (sel.value.indexOf("\n") !== -1) {
      this._applySurround(head, '', exampleKey);
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

  _addText(text, sel) {
    sel = sel || this._getSelected();
    const insert = `${sel.pre}${text}`;
    this.set('value', `${insert}${sel.post}`);
    this._selectText(insert.length, 0);
  },

  actions: {
    bold() {
      this._applySurround('**', '**', 'bold_text');
    },

    italic() {
      this._applySurround('*', '*', 'italic_text');
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
        this._addText(`[${description}](${remaining})`, this._lastSel);
      } else {
        this._addText(`[${link}](${link})`, this._lastSel);
      }

      this.set('link', '');
    },

    code() {
      const sel = this._getSelected();
      if (sel.value.indexOf("\n") !== -1) {
        this._applySurround('    ', '', 'code_text');
      } else {
        this._applySurround('`', '`', 'code_text');
      }
    },

    quote() {
      this._applySurround('> ', "", 'code_text');
    },

    bullet() {
      this._applyList('* ', 'list_item');
    },

    list() {
      this._applyList(i => !i ? "1. " : `${parseInt(i) + 1}. `, 'list_item');
    },

    heading() {
      this._applyList('## ', 'heading_text');
    },

    rule() {
      this._addText("\n\n----------\n");
    },

    emoji() {
      showSelector({
        appendTo: this.$(),
        container: this.container,
        onSelect: title => this._addText(`:${title}:`)
      });
    }
  }

});
