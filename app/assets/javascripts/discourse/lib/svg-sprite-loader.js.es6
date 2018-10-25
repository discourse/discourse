export default {
  name: "svg-sprite-loader",
  load(spritePath, spriteName) {
    const c = "svg-sprites";
    const cEl = `#${c}`;
    const spriteEl = `#${c} .${spriteName}`;

    if ($(cEl).length === 0) $("body").append(`<div id="${c}">`);

    if ($(spriteEl).length === 0) $(cEl).append(`<div class="${spriteName}">`);

    Ember.$.ajax({
      type: "GET",
      dataType: "text",
      url: spritePath,
      success: function(data) {
        $(spriteEl).html(data);
      },
      error: function(req, status, error) {
        console.error(error);
      }
    });
  }
};
