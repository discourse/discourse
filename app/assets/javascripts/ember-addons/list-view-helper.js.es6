import Ember from 'ember';

// TODO - remove this!
var el    = document.body || document.createElement('div');
var style = el.style;
var set   = Ember.set;

function getElementStyle (prop) {
  var uppercaseProp = prop.charAt(0).toUpperCase() + prop.slice(1);

  var props = [
    prop,
    'webkit' + prop,
    'webkit' + uppercaseProp,
    'Moz'    + uppercaseProp,
    'moz'    + uppercaseProp,
    'ms'     + uppercaseProp,
    'ms'     + prop
  ];

  for (var i=0; i < props.length; i++) {
    var property = props[i];

    if (property in style) {
      return property;
    }
  }

  return null;
}

function getCSSStyle (attr) {
  var styleName = getElementStyle(attr);
  var prefix    = styleName.toLowerCase().replace(attr, '');

  var dic = {
    webkit: '-webkit-' + attr,
    moz:    '-moz-' + attr,
    ms:     '-ms-' + attr
  };

  if (prefix && dic[prefix]) {
    return dic[prefix];
  }

  return styleName;
}

var styleAttributeName = getElementStyle('transform');
var transformProp      = getCSSStyle('transform');
var perspectiveProp    = getElementStyle('perspective');
var supports2D         = !!transformProp;
var supports3D         = !!perspectiveProp;

function setStyle (optionalStyleString) {
  return function (obj, x, y) {
    var isElement = obj instanceof Element;

    if (optionalStyleString && (supports2D || supports3D)) {
      var style = Ember.String.fmt(optionalStyleString, x, y);

      if (isElement) {
        obj.style[styleAttributeName] = Ember.String.htmlSafe(style);
      } else {
        set(obj, 'style', Ember.String.htmlSafe(transformProp + ': ' + style));
      }
    } else {
      if (isElement) {
        obj.style.top = y;
        obj.style.left = x;
      }
    }
  };
}

export default {
  transformProp: transformProp,
  applyTransform: (function () {
    if (supports2D) {
      return setStyle('translate(%@px, %@px)');
    }

    return setStyle();
  })(),
  apply3DTransform: (function () {
    if (supports3D) {
      return setStyle('translate3d(%@px, %@px, 0)');
    } else if (supports2D) {
      return setStyle('translate(%@px, %@px)');
    }

    return setStyle();
  })()
};
