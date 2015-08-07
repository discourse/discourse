import RestModel from 'discourse/models/rest';

export default RestModel.extend({
  markdown: Em.computed.equal('format', 'markdown'),
  plainText: Em.computed.equal('format', 'plain'),
  html: Em.computed.equal('format', 'html'),
  css: Em.computed.equal('format', 'css'),
});
