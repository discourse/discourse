/* eslint-disable eqeqeq, no-var, no-console */
// Vendored third-party MiniMasonry library; keep upstream code style verbatim.

/** @type MiniMasonry */
let MiniMasonry = function (conf) {
  this._sizes = [];
  this._columns = [];
  this._container = null;
  this._count = null;
  this._width = 0;
  this._removeListener = null;
  this._currentGutterX = null;
  this._currentGutterY = null;

  ((this._resizeTimeout = null),
    (this.conf = {
      baseWidth: 255,
      gutterX: null,
      gutterY: null,
      gutter: 10,
      container: null,
      minify: true,
      ultimateGutter: 5,
      surroundingGutter: true,
      direction: "ltr",
      wedge: false,
    }));

  this.init(conf);

  return this;
};

MiniMasonry.prototype.init = function (conf) {
  for (let i in this.conf) {
    if (conf[i] != undefined) {
      this.conf[i] = conf[i];
    }
  }

  if (this.conf.gutterX == null || this.conf.gutterY == null) {
    this.conf.gutterX = this.conf.gutterY = this.conf.gutter;
  }
  this._currentGutterX = this.conf.gutterX;
  this._currentGutterY = this.conf.gutterY;

  this._container =
    typeof this.conf.container === "object" && this.conf.container.nodeName
      ? this.conf.container
      : document.querySelector(this.conf.container);

  if (!this._container) {
    throw new Error("Container not found or missing");
  }

  let onResize = this.resizeThrottler.bind(this);
  window.addEventListener("resize", onResize);
  this._removeListener = function () {
    window.removeEventListener("resize", onResize);
    if (this._resizeTimeout != null) {
      window.clearTimeout(this._resizeTimeout);
      this._resizeTimeout = null;
    }
  };

  this.layout();
};

MiniMasonry.prototype.reset = function () {
  this._sizes = [];
  this._columns = [];
  this._count = null;
  this._width = this._container.clientWidth;
  let minWidth = this.conf.baseWidth;
  if (this._width < minWidth) {
    this._width = minWidth;
    this._container.style.minWidth = minWidth + "px";
  }

  if (this.getCount() == 1) {
    // Set ultimate gutter when only one column is displayed
    this._currentGutterX = this.conf.ultimateGutter;
    // As gutters are reduced, two column may fit, forcing to 1
    this._count = 1;
  } else if (this._width < this.conf.baseWidth + 2 * this._currentGutterX) {
    // Remove gutter when screen is to low
    this._currentGutterX = 0;
  } else {
    this._currentGutterX = this.conf.gutterX;
  }
};

MiniMasonry.prototype.getCount = function () {
  if (this.conf.surroundingGutter) {
    return Math.floor(
      (this._width - this._currentGutterX) /
        (this.conf.baseWidth + this._currentGutterX)
    );
  }

  return Math.floor(
    (this._width + this._currentGutterX) /
      (this.conf.baseWidth + this._currentGutterX)
  );
};

MiniMasonry.prototype.computeWidth = function () {
  let width;
  if (this.conf.surroundingGutter) {
    width =
      (this._width - this._currentGutterX) / this._count - this._currentGutterX;
  } else {
    width =
      (this._width + this._currentGutterX) / this._count - this._currentGutterX;
  }
  width = Number.parseFloat(width.toFixed(2));

  return width;
};

MiniMasonry.prototype.layout = function () {
  if (!this._container) {
    console.error("Container not found");
    return;
  }
  this.reset();

  //Computing columns count
  if (this._count == null) {
    this._count = this.getCount();
  }
  //Computing columns width
  let colWidth = this.computeWidth();

  for (let i = 0; i < this._count; i++) {
    this._columns[i] = 0;
  }

  //Saving children real heights
  let children = this._container.children;
  for (let k = 0; k < children.length; k++) {
    // Set colWidth before retrieving element height if content is proportional
    children[k].style.width = colWidth + "px";
    this._sizes[k] = children[k].clientHeight;
  }

  let startX;
  if (this.conf.direction == "ltr") {
    startX = this.conf.surroundingGutter ? this._currentGutterX : 0;
  } else {
    startX =
      this._width - (this.conf.surroundingGutter ? this._currentGutterX : 0);
  }
  if (this._count > this._sizes.length) {
    //If more columns than children
    let occupiedSpace =
      this._sizes.length * (colWidth + this._currentGutterX) -
      this._currentGutterX;
    if (this.conf.wedge === false) {
      if (this.conf.direction == "ltr") {
        startX = (this._width - occupiedSpace) / 2;
      } else {
        startX = this._width - (this._width - occupiedSpace) / 2;
      }
    } else {
      if (this.conf.direction == "ltr") {
        //
      } else {
        startX = this._width - this._currentGutterX;
      }
    }
  }

  //Computing position of children
  for (let index = 0; index < children.length; index++) {
    let nextColumn = this.conf.minify
      ? this.getShortest()
      : this.getNextColumn(index);

    let childrenGutter = 0;
    if (this.conf.surroundingGutter || nextColumn != this._columns.length) {
      childrenGutter = this._currentGutterX;
    }
    var x;
    if (this.conf.direction == "ltr") {
      x = startX + (colWidth + childrenGutter) * nextColumn;
    } else {
      x = startX - (colWidth + childrenGutter) * nextColumn - colWidth;
    }
    let y = this._columns[nextColumn];

    children[index].style.transform =
      "translate3d(" + Math.round(x) + "px," + Math.round(y) + "px,0)";

    this._columns[nextColumn] +=
      this._sizes[index] +
      (this._count > 1 ? this.conf.gutterY : this.conf.ultimateGutter); //margin-bottom
  }

  this._container.style.height =
    this._columns[this.getLongest()] - this._currentGutterY + "px";
};

MiniMasonry.prototype.getNextColumn = function (index) {
  return index % this._columns.length;
};

MiniMasonry.prototype.getShortest = function () {
  let shortest = 0;
  for (let i = 0; i < this._count; i++) {
    if (this._columns[i] < this._columns[shortest]) {
      shortest = i;
    }
  }

  return shortest;
};

MiniMasonry.prototype.getLongest = function () {
  let longest = 0;
  for (let i = 0; i < this._count; i++) {
    if (this._columns[i] > this._columns[longest]) {
      longest = i;
    }
  }

  return longest;
};

MiniMasonry.prototype.resizeThrottler = function () {
  // ignore resize events as long as an actualResizeHandler execution is in the queue
  if (!this._resizeTimeout) {
    this._resizeTimeout = setTimeout(
      function () {
        this._resizeTimeout = null;
        //IOS Safari throw random resize event on scroll, call layout only if size has changed
        if (this._container.clientWidth != this._width) {
          this.layout();
        }
        // The actualResizeHandler will execute at a rate of 30fps
      }.bind(this),
      33
    );
  }
};

MiniMasonry.prototype.destroy = function () {
  if (typeof this._removeListener === "function") {
    this._removeListener();
  }

  let children = this._container.children;
  for (let k = 0; k < children.length; k++) {
    children[k].style.removeProperty("width");
    children[k].style.removeProperty("transform");
  }
  this._container.style.removeProperty("height");
  this._container.style.removeProperty("min-width");
};

export default MiniMasonry;
