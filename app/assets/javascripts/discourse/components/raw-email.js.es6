import Component from "@ember/component";

export default Component.extend({
  html: null,

  didRender() {
    this._super(...arguments);
    const iframeDocument = this.element.children[0].contentWindow.document;
    iframeDocument.open('text/html', 'replace');
    iframeDocument.write(this.html);
    iframeDocument.close();
  }
});
