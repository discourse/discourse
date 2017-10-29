var renderUnboundPreview = function(thumbnails, params) {
  let previewUrl = thumbnails.retina ? (window.devicePixelRatio >= 2 ? thumbnails.retina : thumbnails.normal) : thumbnails;
  if (Discourse.Site.currentProp('mobileView')) return '<img class="thumbnail" src="' + previewUrl + '"/>';
  let attrPrefix = params.isSocial ? 'max-' : '';
  let height = Discourse.SiteSettings.topic_list_thumbnail_height;
  let width = Discourse.SiteSettings.topic_list_thumbnail_width;
  let style = `object-fit:cover;${attrPrefix}height:${height}px;${attrPrefix}width:${width}px`;
  return '<img class="thumbnail" src="' + previewUrl + '" style="' + style + '" />';
};

export default renderUnboundPreview;
