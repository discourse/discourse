/*
 * favcount.js v1.5.0
 * http://chrishunt.co/favcount
 * Dynamically updates the favicon with a number.
 *
 * Copyright 2013, Chris Hunt
 * Released under the MIT license
 */

(function(){
  function Favcount(icon) {
    this.icon = icon;
    this.opacity = 0.4;
    this.canvas = document.createElement('canvas');
    this.font = "Helvetica, Arial, sans-serif";
  }

  Favcount.prototype.set = function(count) {
    var self = this,
        img  = document.createElement('img');

    if (Ember.testing) { return; }

    if (self.canvas.getContext) {
      img.crossOrigin = "anonymous";

      img.onload = function() {
        drawCanvas(self.canvas, self.opacity, self.font, img, normalize(count));
      };

      img.src = this.icon;
    }
  };

  function normalize(count) {
    count = Math.round(count);

    if (isNaN(count) || count < 1) {
      return '';
    } else if (count < 10) {
      return ' ' + count;
    } else if (count > 99) {
      return '99';
    } else {
      return count;
    }
  }

  function drawCanvas(canvas, opacity, font, img, count) {
    var head = document.getElementsByTagName('head')[0],
        favicon = document.createElement('link'),
        multiplier, fontSize, context, xOffset, yOffset, border, shadow;

    favicon.rel = 'icon';

    // Scale canvas elements based on favicon size
    multiplier = img.width / 16;
    fontSize   = multiplier * 11;
    xOffset    = multiplier;
    yOffset    = multiplier * 11;
    border     = multiplier;
    shadow     = multiplier * 2;

    canvas.height = canvas.width = img.width;
    context = canvas.getContext('2d');
    context.font = 'bold ' + fontSize + 'px ' + font;

    // Draw faded favicon background
    if (count) { context.globalAlpha = opacity; }
    context.drawImage(img, 0, 0);
    context.globalAlpha = 1.0;

    // Draw white drop shadow
    context.shadowColor = '#FFF';
    context.shadowBlur = shadow;
    context.shadowOffsetX = 0;
    context.shadowOffsetY = 0;

    // Draw white border
    context.fillStyle = '#FFF';
    context.fillText(count, xOffset, yOffset);
    context.fillText(count, xOffset + border, yOffset);
    context.fillText(count, xOffset, yOffset + border);
    context.fillText(count, xOffset + border, yOffset + border);

    // Draw black count
    context.fillStyle = '#000';
    context.fillText(count,
      xOffset + (border / 2.0),
      yOffset + (border / 2.0)
    );

    // Replace favicon with new favicon
    favicon.href = canvas.toDataURL('image/png');
    head.removeChild(document.querySelector('link[rel=icon]'));
    head.appendChild(favicon);
  }

  Favcount.VERSION = '1.5.0';
  this.Favcount = Favcount;
}).call(this);

