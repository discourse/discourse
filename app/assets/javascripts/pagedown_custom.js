/*global Markdown:true*/

window.PagedownCustom = {
insertButtons: [
  {
    id: 'wmd-quote-post',
    description: I18n.t("js.composer.quote_title"),
    execute: function() {
      /* AWFUL but I can't figure out how to call a controller method from outside
      */

      /* my app?
      */
      return Discourse.__container__.lookup('controller:composer').importQuote();
    }
  }
]
};

window.createNewMarkdownEditor = function(markdownConverter, idPostfix, options) {
  options = options || {};
  options.strings = {
      bold: I18n.t("js.composer.bold_title") + " <strong> Ctrl+B",
      boldexample: I18n.t("js.composer.bold_text"),

      italic: I18n.t("js.composer.italic_title") + " <em> Ctrl+I",
      italicexample: I18n.t("js.composer.italic_text"),

      link: I18n.t("js.composer.link_title") + " <a> Ctrl+L",
      linkdescription: "enter link description here",
      linkdialog: "<p><b>" + I18n.t("js.composer.link_dialog_title") + "</b></p><p>http://example.com/ \"" +
          I18n.t("js.composer.link_optional_text") + "\"</p>",

      quote: I18n.t("js.composer.quote_title") + " <blockquote> Ctrl+Q",
      quoteexample: I18n.t("js.composer.quote_text"),

      code: I18n.t("js.composer.code_title") + " <pre><code> Ctrl+K",
      codeexample: I18n.t("js.composer.code_text"),

      image: I18n.t("js.composer.image_title") + " <img> Ctrl+G",
      imagedescription: I18n.t("js.composer.image_description"),
      imagedialog: "<p><b>" + I18n.t("js.composer.image_dialog_title") + "</b></p><p>http://example.com/images/diagram.jpg \"" +
          I18n.t("js.composer.image_optional_text") + "\"<br><br>" + I18n.t("js.composer.image_hosting_hint") + "</p>",

      olist: I18n.t("js.composer.olist_title") + " <ol> Ctrl+O",
      ulist: I18n.t("js.composer.ulist_title") + " <ul> Ctrl+U",
      litem: I18n.t("js.compser.list_item"),

      heading: I18n.t("js.composer.heading_title") + " <h1>/<h2> Ctrl+H",
      headingexample: I18n.t("js.composer.heading_text"),

      hr: I18n.t("js.composer_hr_title") + " <hr> Ctrl+R",

      undo: I18n.t("js.composer.undo_title") + " - Ctrl+Z",
      redo: I18n.t("js.composer.redo_title") + " - Ctrl+Y",
      redomac: I18n.t("js.composer.redo_title") + " - Ctrl+Shift+Z",

      help: I18n.t("js.composer.help")
  };

  return new Markdown.Editor(markdownConverter, idPostfix, options);
}
