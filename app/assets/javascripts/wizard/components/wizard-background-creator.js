import Component from "@ember/component";

let page = document.getElementsByTagName("html")[0];

let primaryMed = window
  .getComputedStyle(page)
  .getPropertyValue("--primary-medium")
  .trim();

let primaryLowMid = window
  .getComputedStyle(page)
  .getPropertyValue("--primary-low-mid")
  .trim();

const COLORS = [primaryMed, primaryLowMid];

export default Component.extend({
  classNames: ["wizard-background-creator"],
  tagName: "canvas",
  ctx: null,
  ready: false,

  didInsertElement() {
    this._super(...arguments);

    const canvas = this.element;
    this.ctx = canvas.getContext("2d");
    this.resized();

    this.ready = true;
    this.paint();

    $(window).on("resize.wizard", () => this.resized());
  },

  willDestroyElement() {
    this._super(...arguments);
    $(window).off("resize.wizard");
  },

  resized() {
    const canvas = this.element;
    canvas.width = 414;
    canvas.height = 414;
  },

  paint() {
    if (this.isDestroying || this.isDestroyed || !this.ready) {
      return;
    }

    const { ctx } = this;
    ctx.clearRect(0, 0, this.element.width, this.element.height);

    this.drawPattern();
  },

  drawPattern() {
    let fillColor = COLORS[Math.floor(Math.random() * COLORS.length)];

    let ctx = this.ctx;
    // layer1/title
    ctx.save();

    // layer1/title/
    ctx.save();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(162.3, 199.3);
    ctx.bezierCurveTo(162.1, 199.3, 161.8, 199.2, 161.6, 199.1);
    ctx.bezierCurveTo(161.0, 198.8, 160.7, 198.2, 160.8, 197.5);
    ctx.lineTo(163.3, 183.2);
    ctx.bezierCurveTo(163.4, 182.9, 163.2, 182.5, 163.0, 182.3);
    ctx.bezierCurveTo(162.7, 182.1, 162.4, 181.8, 162.0, 181.5);
    ctx.bezierCurveTo(159.4, 179.5, 155.5, 176.5, 155.5, 168.2);
    ctx.bezierCurveTo(155.5, 155.8, 170.1, 150.6, 172.3, 150.2);
    ctx.bezierCurveTo(188.2, 147.6, 200.6, 151.0, 209.2, 160.5);
    ctx.bezierCurveTo(210.0, 161.4, 216.6, 169.1, 212.4, 178.6);
    ctx.bezierCurveTo(207.7, 189.2, 195.8, 194.0, 186.4, 193.2);
    ctx.bezierCurveTo(181.8, 192.8, 177.4, 191.1, 173.6, 188.5);
    ctx.lineTo(163.3, 198.8);
    ctx.bezierCurveTo(163.0, 199.1, 162.7, 199.3, 162.3, 199.3);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(182.1, 151.4);
    ctx.bezierCurveTo(178.9, 151.4, 175.7, 151.7, 172.6, 152.2);
    ctx.bezierCurveTo(172.5, 152.2, 157.4, 156.6, 157.4, 168.2);
    ctx.bezierCurveTo(157.4, 175.6, 160.7, 178.1, 163.2, 179.9);
    ctx.bezierCurveTo(163.6, 180.2, 163.9, 180.5, 164.2, 180.7);
    ctx.bezierCurveTo(165.0, 181.4, 165.4, 182.5, 165.2, 183.5);
    ctx.lineTo(163.0, 196.3);
    ctx.lineTo(172.3, 187.0);
    ctx.bezierCurveTo(172.9, 186.4, 173.8, 186.3, 174.5, 186.8);
    ctx.bezierCurveTo(178.0, 189.3, 182.2, 190.9, 186.5, 191.3);
    ctx.bezierCurveTo(195.1, 192.0, 206.2, 187.7, 210.5, 177.9);
    ctx.bezierCurveTo(214.2, 169.5, 208.4, 162.7, 207.7, 162.0);
    ctx.bezierCurveTo(201.4, 154.9, 192.8, 151.4, 182.1, 151.4);
    ctx.lineTo(182.1, 151.4);
    ctx.closePath();
    ctx.fillStyle = fillColor;
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(169.0, 167.7);
    ctx.bezierCurveTo(170.1, 167.7, 171.0, 168.6, 171.0, 169.7);
    ctx.bezierCurveTo(171.0, 170.8, 170.1, 171.7, 169.0, 171.7);
    ctx.bezierCurveTo(167.9, 171.7, 167.0, 170.8, 167.0, 169.7);
    ctx.bezierCurveTo(167.0, 168.6, 167.9, 167.7, 169.0, 167.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(184.0, 170.7);
    ctx.bezierCurveTo(185.1, 170.7, 186.0, 171.6, 186.0, 172.7);
    ctx.bezierCurveTo(186.0, 173.8, 185.1, 174.7, 184.0, 174.7);
    ctx.bezierCurveTo(182.9, 174.7, 182.0, 173.8, 182.0, 172.7);
    ctx.bezierCurveTo(182.0, 171.6, 182.9, 170.7, 184.0, 170.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(198.0, 172.7);
    ctx.bezierCurveTo(199.1, 172.7, 200.0, 173.6, 200.0, 174.7);
    ctx.bezierCurveTo(200.0, 175.8, 199.1, 176.7, 198.0, 176.7);
    ctx.bezierCurveTo(196.9, 176.7, 196.0, 175.8, 196.0, 174.7);
    ctx.bezierCurveTo(196.0, 173.6, 196.9, 172.7, 198.0, 172.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(206.3, 271.3);
    ctx.bezierCurveTo(206.1, 271.3, 205.8, 271.2, 205.6, 271.1);
    ctx.bezierCurveTo(205.0, 270.8, 204.7, 270.2, 204.8, 269.5);
    ctx.lineTo(207.3, 255.2);
    ctx.bezierCurveTo(207.4, 254.9, 207.2, 254.5, 207.0, 254.3);
    ctx.bezierCurveTo(206.7, 254.1, 206.4, 253.8, 206.0, 253.5);
    ctx.bezierCurveTo(203.4, 251.5, 199.5, 248.5, 199.5, 240.2);
    ctx.bezierCurveTo(199.5, 227.8, 214.1, 222.6, 216.3, 222.2);
    ctx.bezierCurveTo(232.2, 219.6, 244.6, 223.0, 253.2, 232.5);
    ctx.bezierCurveTo(254.0, 233.3, 260.6, 241.1, 256.4, 250.6);
    ctx.bezierCurveTo(251.7, 261.2, 239.7, 266.0, 230.4, 265.2);
    ctx.bezierCurveTo(225.8, 264.8, 221.4, 263.1, 217.6, 260.5);
    ctx.lineTo(207.3, 270.8);
    ctx.bezierCurveTo(207.0, 271.1, 206.7, 271.3, 206.3, 271.3);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(226.1, 223.4);
    ctx.bezierCurveTo(222.9, 223.4, 219.7, 223.7, 216.6, 224.2);
    ctx.bezierCurveTo(216.5, 224.2, 201.4, 228.6, 201.4, 240.2);
    ctx.bezierCurveTo(201.4, 247.6, 204.7, 250.1, 207.2, 251.9);
    ctx.bezierCurveTo(207.6, 252.2, 207.9, 252.5, 208.2, 252.7);
    ctx.bezierCurveTo(209.0, 253.4, 209.4, 254.5, 209.2, 255.5);
    ctx.lineTo(207.0, 268.2);
    ctx.lineTo(216.3, 258.9);
    ctx.bezierCurveTo(216.9, 258.3, 217.8, 258.2, 218.5, 258.7);
    ctx.bezierCurveTo(222.0, 261.2, 226.2, 262.8, 230.5, 263.2);
    ctx.bezierCurveTo(239.1, 263.9, 250.2, 259.6, 254.5, 249.8);
    ctx.bezierCurveTo(258.2, 241.4, 252.4, 234.6, 251.7, 233.9);
    ctx.bezierCurveTo(245.4, 226.9, 236.8, 223.4, 226.1, 223.4);
    ctx.lineTo(226.1, 223.4);
    ctx.closePath();
    ctx.fillStyle = fillColor;
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(213.0, 239.7);
    ctx.bezierCurveTo(214.1, 239.7, 215.0, 240.6, 215.0, 241.7);
    ctx.bezierCurveTo(215.0, 242.8, 214.1, 243.7, 213.0, 243.7);
    ctx.bezierCurveTo(211.9, 243.7, 211.0, 242.8, 211.0, 241.7);
    ctx.bezierCurveTo(211.0, 240.6, 211.9, 239.7, 213.0, 239.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(228.0, 242.7);
    ctx.bezierCurveTo(229.1, 242.7, 230.0, 243.6, 230.0, 244.7);
    ctx.bezierCurveTo(230.0, 245.8, 229.1, 246.7, 228.0, 246.7);
    ctx.bezierCurveTo(226.9, 246.7, 226.0, 245.8, 226.0, 244.7);
    ctx.bezierCurveTo(226.0, 243.6, 226.9, 242.7, 228.0, 242.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(242.0, 244.7);
    ctx.bezierCurveTo(243.1, 244.7, 244.0, 245.6, 244.0, 246.7);
    ctx.bezierCurveTo(244.0, 247.8, 243.1, 248.7, 242.0, 248.7);
    ctx.bezierCurveTo(240.9, 248.7, 240.0, 247.8, 240.0, 246.7);
    ctx.bezierCurveTo(240.0, 245.6, 240.9, 244.7, 242.0, 244.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(93.3, 238.3);
    ctx.bezierCurveTo(93.1, 238.3, 92.8, 238.2, 92.6, 238.1);
    ctx.bezierCurveTo(92.0, 237.8, 91.7, 237.2, 91.8, 236.5);
    ctx.lineTo(94.3, 222.2);
    ctx.bezierCurveTo(94.4, 221.9, 94.2, 221.5, 94.0, 221.3);
    ctx.bezierCurveTo(93.7, 221.1, 93.4, 220.8, 93.0, 220.5);
    ctx.bezierCurveTo(90.4, 218.5, 86.5, 215.5, 86.5, 207.2);
    ctx.bezierCurveTo(86.5, 194.8, 101.1, 189.6, 103.3, 189.2);
    ctx.bezierCurveTo(119.2, 186.6, 131.6, 190.0, 140.2, 199.5);
    ctx.bezierCurveTo(141.0, 200.4, 147.6, 208.1, 143.4, 217.6);
    ctx.bezierCurveTo(138.7, 228.2, 126.8, 233.0, 117.4, 232.2);
    ctx.bezierCurveTo(112.8, 231.8, 108.4, 230.1, 104.6, 227.5);
    ctx.lineTo(94.3, 237.8);
    ctx.bezierCurveTo(94.0, 238.1, 93.7, 238.3, 93.3, 238.3);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(113.1, 190.4);
    ctx.bezierCurveTo(109.9, 190.4, 106.7, 190.7, 103.6, 191.2);
    ctx.bezierCurveTo(103.4, 191.2, 88.4, 195.6, 88.4, 207.2);
    ctx.bezierCurveTo(88.4, 214.6, 91.7, 217.1, 94.2, 218.9);
    ctx.bezierCurveTo(94.6, 219.2, 94.9, 219.5, 95.2, 219.7);
    ctx.bezierCurveTo(96.0, 220.4, 96.4, 221.5, 96.2, 222.5);
    ctx.lineTo(94.0, 235.3);
    ctx.lineTo(103.3, 226.0);
    ctx.bezierCurveTo(103.9, 225.4, 104.8, 225.3, 105.5, 225.8);
    ctx.bezierCurveTo(109.0, 228.3, 113.2, 229.9, 117.5, 230.3);
    ctx.bezierCurveTo(126.1, 231.0, 137.2, 226.7, 141.5, 216.9);
    ctx.bezierCurveTo(145.2, 208.5, 139.4, 201.7, 138.7, 201.0);
    ctx.bezierCurveTo(132.4, 193.9, 123.8, 190.4, 113.1, 190.4);
    ctx.closePath();
    ctx.fillStyle = fillColor;
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(100.0, 206.7);
    ctx.bezierCurveTo(101.1, 206.7, 102.0, 207.6, 102.0, 208.7);
    ctx.bezierCurveTo(102.0, 209.8, 101.1, 210.7, 100.0, 210.7);
    ctx.bezierCurveTo(98.9, 210.7, 98.0, 209.8, 98.0, 208.7);
    ctx.bezierCurveTo(98.0, 207.6, 98.9, 206.7, 100.0, 206.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(115.0, 209.7);
    ctx.bezierCurveTo(116.1, 209.7, 117.0, 210.6, 117.0, 211.7);
    ctx.bezierCurveTo(117.0, 212.8, 116.1, 213.7, 115.0, 213.7);
    ctx.bezierCurveTo(113.9, 213.7, 113.0, 212.8, 113.0, 211.7);
    ctx.bezierCurveTo(113.0, 210.6, 113.9, 209.7, 115.0, 209.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(129.0, 211.7);
    ctx.bezierCurveTo(130.1, 211.7, 131.0, 212.6, 131.0, 213.7);
    ctx.bezierCurveTo(131.0, 214.8, 130.1, 215.7, 129.0, 215.7);
    ctx.bezierCurveTo(127.9, 215.7, 127.0, 214.8, 127.0, 213.7);
    ctx.bezierCurveTo(127.0, 212.6, 127.9, 211.7, 129.0, 211.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(9.2, 37.2);
    ctx.bezierCurveTo(6.5, 34.2, 3.5, 31.8, 0.0, 30.0);
    ctx.lineTo(0.0, 32.4);
    ctx.bezierCurveTo(2.9, 34.0, 5.5, 36.1, 7.7, 38.7);
    ctx.bezierCurveTo(8.4, 39.4, 14.2, 46.2, 10.5, 54.6);
    ctx.bezierCurveTo(8.3, 59.5, 4.5, 63.1, 0.0, 65.3);
    ctx.lineTo(0.0, 67.4);
    ctx.bezierCurveTo(5.2, 65.0, 9.9, 61.0, 12.4, 55.3);
    ctx.bezierCurveTo(16.6, 45.8, 10.0, 38.1, 9.2, 37.2);
    ctx.closePath();
    ctx.fillStyle = fillColor;
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(386.6, 28.9);
    ctx.bezierCurveTo(389.8, 28.3, 392.9, 28.1, 396.1, 28.1);
    ctx.bezierCurveTo(403.5, 28.1, 409.9, 29.7, 415.2, 33.1);
    ctx.lineTo(415.2, 30.7);
    ctx.bezierCurveTo(407.5, 26.2, 397.8, 25.0, 386.3, 26.9);
    ctx.bezierCurveTo(384.1, 27.3, 369.5, 32.5, 369.5, 44.9);
    ctx.bezierCurveTo(369.5, 53.2, 373.4, 56.2, 376.0, 58.2);
    ctx.bezierCurveTo(376.4, 58.5, 376.7, 58.8, 377.0, 59.0);
    ctx.bezierCurveTo(377.3, 59.2, 377.4, 59.5, 377.3, 59.9);
    ctx.lineTo(374.8, 74.2);
    ctx.bezierCurveTo(374.7, 74.8, 375.0, 75.5, 375.6, 75.8);
    ctx.bezierCurveTo(375.8, 75.9, 376.1, 75.9, 376.3, 76.0);
    ctx.bezierCurveTo(376.7, 75.9, 377.0, 75.7, 377.3, 75.5);
    ctx.lineTo(387.6, 65.2);
    ctx.bezierCurveTo(391.4, 67.8, 395.8, 69.4, 400.4, 69.9);
    ctx.bezierCurveTo(405.1, 70.3, 410.5, 69.3, 415.2, 66.8);
    ctx.lineTo(415.2, 64.6);
    ctx.bezierCurveTo(410.6, 67.3, 405.2, 68.3, 400.5, 68.0);
    ctx.bezierCurveTo(396.2, 67.5, 392.0, 66.0, 388.5, 63.5);
    ctx.bezierCurveTo(387.8, 63.0, 386.9, 63.1, 386.3, 63.7);
    ctx.lineTo(377.0, 73.0);
    ctx.lineTo(379.2, 60.2);
    ctx.bezierCurveTo(379.4, 59.1, 379.0, 58.0, 378.2, 57.4);
    ctx.bezierCurveTo(377.9, 57.2, 377.6, 56.9, 377.2, 56.6);
    ctx.bezierCurveTo(374.7, 54.8, 371.4, 52.3, 371.4, 44.9);
    ctx.bezierCurveTo(371.4, 33.3, 386.4, 28.9, 386.6, 28.9);
    ctx.closePath();
    ctx.fillStyle = fillColor;
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(383.0, 44.4);
    ctx.bezierCurveTo(384.1, 44.4, 385.0, 45.3, 385.0, 46.4);
    ctx.bezierCurveTo(385.0, 47.5, 384.1, 48.4, 383.0, 48.4);
    ctx.bezierCurveTo(381.9, 48.4, 381.0, 47.5, 381.0, 46.4);
    ctx.bezierCurveTo(381.0, 45.3, 381.9, 44.4, 383.0, 44.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(398.0, 47.4);
    ctx.bezierCurveTo(399.1, 47.4, 400.0, 48.3, 400.0, 49.4);
    ctx.bezierCurveTo(400.0, 50.5, 399.1, 51.4, 398.0, 51.4);
    ctx.bezierCurveTo(396.9, 51.4, 396.0, 50.5, 396.0, 49.4);
    ctx.bezierCurveTo(396.0, 48.3, 396.9, 47.4, 398.0, 47.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(412.0, 49.4);
    ctx.bezierCurveTo(413.1, 49.4, 414.0, 50.3, 414.0, 51.4);
    ctx.bezierCurveTo(414.0, 52.5, 413.1, 53.4, 412.0, 53.4);
    ctx.bezierCurveTo(410.9, 53.4, 410.0, 52.5, 410.0, 51.4);
    ctx.bezierCurveTo(410.0, 50.3, 410.9, 49.4, 412.0, 49.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(320.3, 301.3);
    ctx.bezierCurveTo(320.1, 301.3, 319.8, 301.2, 319.6, 301.1);
    ctx.bezierCurveTo(319.0, 300.8, 318.7, 300.2, 318.8, 299.5);
    ctx.lineTo(321.3, 285.2);
    ctx.bezierCurveTo(321.4, 284.9, 321.2, 284.5, 321.0, 284.3);
    ctx.bezierCurveTo(320.7, 284.1, 320.4, 283.8, 320.0, 283.5);
    ctx.bezierCurveTo(317.4, 281.5, 313.5, 278.5, 313.5, 270.2);
    ctx.bezierCurveTo(313.5, 257.8, 328.1, 252.6, 330.3, 252.2);
    ctx.bezierCurveTo(346.2, 249.6, 358.6, 253.0, 367.2, 262.5);
    ctx.bezierCurveTo(368.0, 263.3, 374.6, 271.0, 370.4, 280.6);
    ctx.bezierCurveTo(365.7, 291.2, 353.7, 296.0, 344.4, 295.2);
    ctx.bezierCurveTo(339.8, 294.8, 335.4, 293.1, 331.6, 290.5);
    ctx.lineTo(321.3, 300.8);
    ctx.bezierCurveTo(321.0, 301.1, 320.7, 301.3, 320.3, 301.3);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(340.1, 253.4);
    ctx.bezierCurveTo(336.9, 253.4, 333.7, 253.7, 330.6, 254.2);
    ctx.bezierCurveTo(330.5, 254.2, 315.4, 258.6, 315.4, 270.2);
    ctx.bezierCurveTo(315.4, 277.6, 318.7, 280.1, 321.2, 281.9);
    ctx.bezierCurveTo(321.6, 282.2, 321.9, 282.5, 322.2, 282.7);
    ctx.bezierCurveTo(323.0, 283.4, 323.4, 284.5, 323.2, 285.5);
    ctx.lineTo(321.0, 298.3);
    ctx.lineTo(330.3, 289.0);
    ctx.bezierCurveTo(330.9, 288.4, 331.8, 288.3, 332.5, 288.8);
    ctx.bezierCurveTo(336.0, 291.3, 340.2, 292.9, 344.5, 293.3);
    ctx.bezierCurveTo(353.1, 294.0, 364.2, 289.7, 368.5, 279.9);
    ctx.bezierCurveTo(372.2, 271.5, 366.4, 264.7, 365.7, 264.0);
    ctx.bezierCurveTo(359.4, 256.9, 350.8, 253.4, 340.1, 253.4);
    ctx.lineTo(340.1, 253.4);
    ctx.closePath();
    ctx.fillStyle = fillColor;
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(327.0, 269.7);
    ctx.bezierCurveTo(328.1, 269.7, 329.0, 270.6, 329.0, 271.7);
    ctx.bezierCurveTo(329.0, 272.8, 328.1, 273.7, 327.0, 273.7);
    ctx.bezierCurveTo(325.9, 273.7, 325.0, 272.8, 325.0, 271.7);
    ctx.bezierCurveTo(325.0, 270.6, 325.9, 269.7, 327.0, 269.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(342.0, 272.7);
    ctx.bezierCurveTo(343.1, 272.7, 344.0, 273.6, 344.0, 274.7);
    ctx.bezierCurveTo(344.0, 275.8, 343.1, 276.7, 342.0, 276.7);
    ctx.bezierCurveTo(340.9, 276.7, 340.0, 275.8, 340.0, 274.7);
    ctx.bezierCurveTo(340.0, 273.6, 340.9, 272.7, 342.0, 272.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(356.0, 274.7);
    ctx.bezierCurveTo(357.1, 274.7, 358.0, 275.6, 358.0, 276.7);
    ctx.bezierCurveTo(358.0, 277.8, 357.1, 278.7, 356.0, 278.7);
    ctx.bezierCurveTo(354.9, 278.7, 354.0, 277.8, 354.0, 276.7);
    ctx.bezierCurveTo(354.0, 275.6, 354.9, 274.7, 356.0, 274.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(355.3, 194.3);
    ctx.bezierCurveTo(355.1, 194.3, 354.8, 194.2, 354.6, 194.1);
    ctx.bezierCurveTo(354.0, 193.8, 353.7, 193.2, 353.8, 192.5);
    ctx.lineTo(356.3, 178.2);
    ctx.bezierCurveTo(356.4, 177.9, 356.2, 177.5, 356.0, 177.3);
    ctx.bezierCurveTo(355.7, 177.1, 355.4, 176.8, 355.0, 176.5);
    ctx.bezierCurveTo(352.4, 174.5, 348.5, 171.5, 348.5, 163.2);
    ctx.bezierCurveTo(348.5, 150.8, 363.1, 145.6, 365.3, 145.2);
    ctx.bezierCurveTo(381.2, 142.6, 393.6, 146.0, 402.2, 155.5);
    ctx.bezierCurveTo(403.0, 156.4, 409.6, 164.1, 405.4, 173.6);
    ctx.bezierCurveTo(400.7, 184.2, 388.7, 189.0, 379.4, 188.2);
    ctx.bezierCurveTo(374.8, 187.8, 370.4, 186.1, 366.6, 183.5);
    ctx.lineTo(356.3, 193.8);
    ctx.bezierCurveTo(356.0, 194.1, 355.7, 194.3, 355.3, 194.3);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(375.1, 146.4);
    ctx.bezierCurveTo(371.9, 146.4, 368.7, 146.7, 365.6, 147.2);
    ctx.bezierCurveTo(365.5, 147.2, 350.4, 151.6, 350.4, 163.2);
    ctx.bezierCurveTo(350.4, 170.6, 353.7, 173.1, 356.2, 174.9);
    ctx.bezierCurveTo(356.6, 175.2, 356.9, 175.5, 357.2, 175.7);
    ctx.bezierCurveTo(358.0, 176.4, 358.4, 177.5, 358.2, 178.5);
    ctx.lineTo(356.0, 191.3);
    ctx.lineTo(365.3, 182.0);
    ctx.bezierCurveTo(365.9, 181.4, 366.8, 181.3, 367.5, 181.8);
    ctx.bezierCurveTo(371.0, 184.3, 375.2, 185.9, 379.5, 186.3);
    ctx.bezierCurveTo(388.2, 187.0, 399.2, 182.7, 403.5, 172.9);
    ctx.bezierCurveTo(407.2, 164.5, 401.4, 157.7, 400.7, 157.0);
    ctx.bezierCurveTo(394.4, 149.9, 385.8, 146.4, 375.1, 146.4);
    ctx.lineTo(375.1, 146.4);
    ctx.closePath();
    ctx.fillStyle = fillColor;
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(362.0, 162.7);
    ctx.bezierCurveTo(363.1, 162.7, 364.0, 163.6, 364.0, 164.7);
    ctx.bezierCurveTo(364.0, 165.8, 363.1, 166.7, 362.0, 166.7);
    ctx.bezierCurveTo(360.9, 166.7, 360.0, 165.8, 360.0, 164.7);
    ctx.bezierCurveTo(360.0, 163.6, 360.9, 162.7, 362.0, 162.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(377.0, 165.7);
    ctx.bezierCurveTo(378.1, 165.7, 379.0, 166.6, 379.0, 167.7);
    ctx.bezierCurveTo(379.0, 168.8, 378.1, 169.7, 377.0, 169.7);
    ctx.bezierCurveTo(375.9, 169.7, 375.0, 168.8, 375.0, 167.7);
    ctx.bezierCurveTo(375.0, 166.6, 375.9, 165.7, 377.0, 165.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(391.0, 167.7);
    ctx.bezierCurveTo(392.1, 167.7, 393.0, 168.6, 393.0, 169.7);
    ctx.bezierCurveTo(393.0, 170.8, 392.1, 171.7, 391.0, 171.7);
    ctx.bezierCurveTo(389.9, 171.7, 389.0, 170.8, 389.0, 169.7);
    ctx.bezierCurveTo(389.0, 168.6, 389.9, 167.7, 391.0, 167.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(289.3, 125.3);
    ctx.bezierCurveTo(289.1, 125.3, 288.8, 125.2, 288.6, 125.1);
    ctx.bezierCurveTo(288.0, 124.8, 287.7, 124.2, 287.8, 123.5);
    ctx.lineTo(290.3, 109.2);
    ctx.bezierCurveTo(290.4, 108.9, 290.2, 108.5, 290.0, 108.3);
    ctx.bezierCurveTo(289.7, 108.1, 289.4, 107.8, 289.0, 107.5);
    ctx.bezierCurveTo(286.4, 105.5, 282.5, 102.5, 282.5, 94.2);
    ctx.bezierCurveTo(282.5, 81.9, 297.1, 76.6, 299.3, 76.2);
    ctx.bezierCurveTo(315.2, 73.6, 327.6, 77.0, 336.2, 86.5);
    ctx.bezierCurveTo(337.0, 87.3, 343.6, 95.1, 339.4, 104.6);
    ctx.bezierCurveTo(334.7, 115.2, 322.7, 120.0, 313.4, 119.2);
    ctx.bezierCurveTo(308.8, 118.8, 304.4, 117.1, 300.6, 114.5);
    ctx.lineTo(290.3, 124.8);
    ctx.bezierCurveTo(290.0, 125.1, 289.7, 125.3, 289.3, 125.3);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(309.1, 77.4);
    ctx.bezierCurveTo(305.9, 77.4, 302.7, 77.7, 299.6, 78.2);
    ctx.bezierCurveTo(299.5, 78.2, 284.4, 82.6, 284.4, 94.2);
    ctx.bezierCurveTo(284.4, 101.5, 287.7, 104.1, 290.2, 105.9);
    ctx.bezierCurveTo(290.6, 106.2, 290.9, 106.5, 291.2, 106.7);
    ctx.bezierCurveTo(292.0, 107.4, 292.4, 108.5, 292.2, 109.5);
    ctx.lineTo(290.0, 122.3);
    ctx.lineTo(299.3, 113.0);
    ctx.bezierCurveTo(299.9, 112.4, 300.8, 112.3, 301.5, 112.8);
    ctx.bezierCurveTo(305.0, 115.3, 309.2, 116.9, 313.5, 117.3);
    ctx.bezierCurveTo(322.2, 118.0, 333.2, 113.6, 337.5, 103.9);
    ctx.bezierCurveTo(341.2, 95.5, 335.4, 88.7, 334.7, 88.0);
    ctx.bezierCurveTo(328.4, 80.9, 319.8, 77.4, 309.1, 77.4);
    ctx.lineTo(309.1, 77.4);
    ctx.closePath();
    ctx.fillStyle = fillColor;
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(296.0, 93.7);
    ctx.bezierCurveTo(297.1, 93.7, 298.0, 94.6, 298.0, 95.7);
    ctx.bezierCurveTo(298.0, 96.8, 297.1, 97.7, 296.0, 97.7);
    ctx.bezierCurveTo(294.9, 97.7, 294.0, 96.8, 294.0, 95.7);
    ctx.bezierCurveTo(294.0, 94.6, 294.9, 93.7, 296.0, 93.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(311.0, 96.7);
    ctx.bezierCurveTo(312.1, 96.7, 313.0, 97.6, 313.0, 98.7);
    ctx.bezierCurveTo(313.0, 99.8, 312.1, 100.7, 311.0, 100.7);
    ctx.bezierCurveTo(309.9, 100.7, 309.0, 99.8, 309.0, 98.7);
    ctx.bezierCurveTo(309.0, 97.6, 309.9, 96.7, 311.0, 96.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(325.0, 98.7);
    ctx.bezierCurveTo(326.1, 98.7, 327.0, 99.6, 327.0, 100.7);
    ctx.bezierCurveTo(327.0, 101.8, 326.1, 102.7, 325.0, 102.7);
    ctx.bezierCurveTo(323.9, 102.7, 323.0, 101.8, 323.0, 100.7);
    ctx.bezierCurveTo(323.0, 99.6, 323.9, 98.7, 325.0, 98.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(83.1, 111.3);
    ctx.bezierCurveTo(83.0, 111.3, 82.8, 111.3, 82.6, 111.3);
    ctx.bezierCurveTo(82.1, 111.3, 81.7, 110.9, 81.6, 110.4);
    ctx.lineTo(79.6, 99.7);
    ctx.bezierCurveTo(79.5, 99.4, 79.4, 99.2, 79.1, 99.1);
    ctx.bezierCurveTo(78.9, 99.1, 78.6, 99.0, 78.2, 98.9);
    ctx.bezierCurveTo(75.8, 98.2, 72.2, 97.1, 69.9, 91.3);
    ctx.bezierCurveTo(66.6, 82.7, 75.8, 74.9, 77.3, 74.0);
    ctx.bezierCurveTo(88.2, 67.8, 98.1, 66.8, 106.8, 71.0);
    ctx.bezierCurveTo(107.6, 71.4, 114.5, 75.0, 114.0, 82.9);
    ctx.bezierCurveTo(113.4, 91.6, 106.0, 98.3, 99.0, 100.3);
    ctx.bezierCurveTo(95.5, 101.3, 91.9, 101.3, 88.4, 100.5);
    ctx.lineTo(83.7, 110.6);
    ctx.bezierCurveTo(83.6, 110.9, 83.4, 111.2, 83.1, 111.3);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(84.7, 72.2);
    ctx.bezierCurveTo(82.4, 73.1, 80.2, 74.2, 78.0, 75.4);
    ctx.bezierCurveTo(77.9, 75.4, 68.1, 82.7, 71.2, 90.8);
    ctx.bezierCurveTo(73.2, 96.0, 76.2, 96.8, 78.6, 97.4);
    ctx.bezierCurveTo(78.9, 97.5, 79.2, 97.7, 79.5, 97.7);
    ctx.bezierCurveTo(80.3, 98.0, 80.9, 98.6, 81.0, 99.4);
    ctx.lineTo(82.8, 109.0);
    ctx.lineTo(87.1, 99.9);
    ctx.bezierCurveTo(87.4, 99.3, 88.0, 99.0, 88.7, 99.2);
    ctx.bezierCurveTo(91.9, 100.0, 95.3, 100.0, 98.6, 99.1);
    ctx.bezierCurveTo(105.1, 97.1, 111.9, 91.1, 112.4, 83.1);
    ctx.bezierCurveTo(112.9, 76.1, 106.8, 73.0, 106.1, 72.7);
    ctx.bezierCurveTo(99.7, 69.4, 92.5, 69.3, 84.7, 72.2);
    ctx.closePath();
    ctx.fillStyle = fillColor;
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(79.6, 87.3);
    ctx.bezierCurveTo(80.4, 87.0, 81.3, 87.4, 81.5, 88.1);
    ctx.bezierCurveTo(81.8, 88.9, 81.4, 89.8, 80.6, 90.1);
    ctx.bezierCurveTo(79.8, 90.4, 78.9, 90.0, 78.6, 89.2);
    ctx.bezierCurveTo(78.4, 88.5, 78.8, 87.6, 79.6, 87.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(91.3, 85.3);
    ctx.bezierCurveTo(92.1, 85.0, 92.9, 85.3, 93.2, 86.1);
    ctx.bezierCurveTo(93.5, 86.9, 93.1, 87.8, 92.3, 88.1);
    ctx.bezierCurveTo(91.5, 88.4, 90.6, 88.0, 90.3, 87.2);
    ctx.bezierCurveTo(90.0, 86.4, 90.5, 85.6, 91.3, 85.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(102.0, 82.8);
    ctx.bezierCurveTo(102.8, 82.5, 103.6, 82.9, 103.9, 83.6);
    ctx.bezierCurveTo(104.2, 84.4, 103.8, 85.3, 103.0, 85.6);
    ctx.bezierCurveTo(102.2, 85.9, 101.3, 85.5, 101.0, 84.7);
    ctx.bezierCurveTo(100.7, 84.0, 101.2, 83.1, 102.0, 82.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(182.5, 107.5);
    ctx.bezierCurveTo(182.3, 107.6, 182.2, 107.6, 182.0, 107.5);
    ctx.bezierCurveTo(181.6, 107.5, 181.3, 107.2, 181.2, 106.8);
    ctx.lineTo(179.5, 98.0);
    ctx.bezierCurveTo(179.5, 97.8, 179.4, 97.6, 179.2, 97.5);
    ctx.bezierCurveTo(178.9, 97.5, 178.7, 97.4, 178.4, 97.3);
    ctx.bezierCurveTo(176.4, 96.7, 173.4, 95.9, 171.6, 91.1);
    ctx.bezierCurveTo(168.9, 84.0, 176.4, 77.6, 177.7, 76.9);
    ctx.bezierCurveTo(186.6, 71.7, 194.7, 70.9, 202.0, 74.4);
    ctx.bezierCurveTo(202.6, 74.7, 208.3, 77.7, 207.9, 84.1);
    ctx.bezierCurveTo(207.4, 91.3, 201.3, 96.8, 195.5, 98.5);
    ctx.bezierCurveTo(192.7, 99.3, 189.7, 99.3, 186.9, 98.7);
    ctx.lineTo(183.0, 107.0);
    ctx.bezierCurveTo(182.9, 107.2, 182.7, 107.4, 182.5, 107.5);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(183.8, 75.4);
    ctx.bezierCurveTo(181.9, 76.1, 180.0, 77.0, 178.3, 78.0);
    ctx.bezierCurveTo(178.2, 78.0, 170.2, 84.0, 172.7, 90.7);
    ctx.bezierCurveTo(174.3, 94.9, 176.9, 95.7, 178.7, 96.1);
    ctx.bezierCurveTo(179.0, 96.2, 179.3, 96.3, 179.5, 96.4);
    ctx.bezierCurveTo(180.1, 96.6, 180.6, 97.1, 180.7, 97.7);
    ctx.lineTo(182.2, 105.6);
    ctx.lineTo(185.7, 98.2);
    ctx.bezierCurveTo(186.0, 97.7, 186.5, 97.5, 187.0, 97.6);
    ctx.bezierCurveTo(189.7, 98.2, 192.5, 98.2, 195.2, 97.5);
    ctx.bezierCurveTo(200.5, 95.9, 206.2, 90.8, 206.6, 84.3);
    ctx.bezierCurveTo(206.9, 78.6, 202.0, 76.0, 201.4, 75.7);
    ctx.bezierCurveTo(196.1, 73.0, 190.2, 72.9, 183.8, 75.4);
    ctx.closePath();
    ctx.fillStyle = fillColor;
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(179.5, 87.8);
    ctx.bezierCurveTo(180.2, 87.5, 180.9, 87.8, 181.2, 88.5);
    ctx.bezierCurveTo(181.4, 89.1, 181.1, 89.8, 180.4, 90.1);
    ctx.bezierCurveTo(179.8, 90.3, 179.0, 90.0, 178.8, 89.4);
    ctx.bezierCurveTo(178.5, 88.7, 178.9, 88.0, 179.5, 87.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(189.1, 86.1);
    ctx.bezierCurveTo(189.8, 85.8, 190.5, 86.1, 190.8, 86.8);
    ctx.bezierCurveTo(191.0, 87.4, 190.7, 88.2, 190.0, 88.4);
    ctx.bezierCurveTo(189.4, 88.7, 188.6, 88.3, 188.4, 87.7);
    ctx.bezierCurveTo(188.1, 87.1, 188.5, 86.3, 189.1, 86.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(197.9, 84.1);
    ctx.bezierCurveTo(198.6, 83.8, 199.3, 84.1, 199.6, 84.8);
    ctx.bezierCurveTo(199.8, 85.4, 199.5, 86.1, 198.8, 86.4);
    ctx.bezierCurveTo(198.2, 86.6, 197.4, 86.3, 197.2, 85.7);
    ctx.bezierCurveTo(196.9, 85.0, 197.3, 84.3, 197.9, 84.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(177.4, 74.0);
    ctx.bezierCurveTo(177.3, 74.0, 177.1, 74.0, 176.9, 74.0);
    ctx.bezierCurveTo(176.5, 74.0, 176.2, 73.7, 176.1, 73.3);
    ctx.lineTo(174.5, 64.4);
    ctx.bezierCurveTo(174.4, 64.2, 174.3, 64.1, 174.1, 64.0);
    ctx.bezierCurveTo(173.9, 64.0, 173.6, 63.8, 173.3, 63.7);
    ctx.bezierCurveTo(171.3, 63.2, 168.3, 62.3, 166.5, 57.5);
    ctx.bezierCurveTo(163.8, 50.4, 171.4, 44.1, 172.6, 43.3);
    ctx.bezierCurveTo(181.5, 38.2, 189.7, 37.3, 196.9, 40.9);
    ctx.bezierCurveTo(197.5, 41.2, 203.2, 44.2, 202.8, 50.6);
    ctx.bezierCurveTo(202.3, 57.8, 196.2, 63.3, 190.5, 65.0);
    ctx.bezierCurveTo(187.6, 65.7, 184.7, 65.8, 181.8, 65.1);
    ctx.lineTo(177.9, 73.4);
    ctx.bezierCurveTo(177.8, 73.7, 177.6, 73.9, 177.4, 74.0);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(178.7, 41.8);
    ctx.bezierCurveTo(176.8, 42.6, 175.0, 43.5, 173.2, 44.5);
    ctx.bezierCurveTo(173.2, 44.5, 165.1, 50.5, 167.7, 57.1);
    ctx.bezierCurveTo(169.3, 61.4, 171.8, 62.1, 173.7, 62.6);
    ctx.bezierCurveTo(174.0, 62.7, 174.2, 62.8, 174.4, 62.8);
    ctx.bezierCurveTo(175.1, 63.0, 175.5, 63.6, 175.7, 64.2);
    ctx.lineTo(177.2, 72.1);
    ctx.lineTo(180.7, 64.6);
    ctx.bezierCurveTo(180.9, 64.1, 181.5, 63.8, 182.0, 64.0);
    ctx.bezierCurveTo(184.7, 64.7, 187.5, 64.6, 190.2, 63.9);
    ctx.bezierCurveTo(195.5, 62.3, 201.1, 57.3, 201.6, 50.7);
    ctx.bezierCurveTo(201.9, 45.0, 196.9, 42.4, 196.4, 42.1);
    ctx.bezierCurveTo(191.0, 39.5, 185.1, 39.4, 178.7, 41.8);
    ctx.closePath();
    ctx.fillStyle = fillColor;
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(174.5, 54.2);
    ctx.bezierCurveTo(175.1, 54.0, 175.9, 54.3, 176.1, 54.9);
    ctx.bezierCurveTo(176.3, 55.6, 176.0, 56.3, 175.3, 56.5);
    ctx.bezierCurveTo(174.7, 56.8, 174.0, 56.5, 173.7, 55.8);
    ctx.bezierCurveTo(173.5, 55.2, 173.8, 54.5, 174.5, 54.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(184.1, 52.6);
    ctx.bezierCurveTo(184.8, 52.3, 185.5, 52.6, 185.7, 53.3);
    ctx.bezierCurveTo(186.0, 53.9, 185.6, 54.6, 185.0, 54.9);
    ctx.bezierCurveTo(184.3, 55.1, 183.6, 54.8, 183.3, 54.2);
    ctx.bezierCurveTo(183.1, 53.5, 183.4, 52.8, 184.1, 52.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(192.9, 50.5);
    ctx.bezierCurveTo(193.5, 50.3, 194.3, 50.6, 194.5, 51.2);
    ctx.bezierCurveTo(194.8, 51.9, 194.4, 52.6, 193.8, 52.8);
    ctx.bezierCurveTo(193.1, 53.1, 192.4, 52.8, 192.1, 52.1);
    ctx.bezierCurveTo(191.9, 51.5, 192.2, 50.8, 192.9, 50.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(77.4, 151.4);
    ctx.bezierCurveTo(77.3, 151.4, 77.1, 151.4, 77.0, 151.4);
    ctx.bezierCurveTo(76.6, 151.3, 76.2, 151.0, 76.2, 150.6);
    ctx.lineTo(74.5, 141.8);
    ctx.bezierCurveTo(74.5, 141.6, 74.3, 141.4, 74.1, 141.3);
    ctx.bezierCurveTo(73.9, 141.3, 73.7, 141.2, 73.4, 141.1);
    ctx.bezierCurveTo(71.4, 140.5, 68.4, 139.7, 66.6, 134.9);
    ctx.bezierCurveTo(63.9, 127.8, 71.4, 121.4, 72.6, 120.7);
    ctx.bezierCurveTo(81.6, 115.6, 89.7, 114.7, 96.9, 118.2);
    ctx.bezierCurveTo(97.6, 118.5, 103.2, 121.5, 102.8, 128.0);
    ctx.bezierCurveTo(102.3, 135.2, 96.2, 140.7, 90.5, 142.3);
    ctx.bezierCurveTo(87.7, 143.1, 84.7, 143.2, 81.8, 142.5);
    ctx.lineTo(77.9, 150.8);
    ctx.bezierCurveTo(77.9, 151.0, 77.7, 151.2, 77.4, 151.4);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(78.8, 119.2);
    ctx.bezierCurveTo(76.9, 119.9, 75.0, 120.8, 73.3, 121.8);
    ctx.bezierCurveTo(73.2, 121.8, 65.1, 127.8, 67.7, 134.5);
    ctx.bezierCurveTo(69.3, 138.7, 71.8, 139.5, 73.7, 140.0);
    ctx.bezierCurveTo(74.0, 140.0, 74.2, 140.1, 74.5, 140.2);
    ctx.bezierCurveTo(75.1, 140.4, 75.6, 140.9, 75.7, 141.6);
    ctx.lineTo(77.2, 149.5);
    ctx.lineTo(80.7, 142.0);
    ctx.bezierCurveTo(80.9, 141.5, 81.4, 141.2, 81.9, 141.4);
    ctx.bezierCurveTo(84.6, 142.0, 87.4, 142.0, 90.1, 141.2);
    ctx.bezierCurveTo(95.5, 139.7, 101.1, 134.6, 101.5, 128.0);
    ctx.bezierCurveTo(101.9, 122.4, 96.9, 119.7, 96.3, 119.5);
    ctx.bezierCurveTo(91.1, 116.8, 85.1, 116.8, 78.8, 119.2);
    ctx.closePath();
    ctx.fillStyle = fillColor;
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(74.5, 131.6);
    ctx.bezierCurveTo(75.2, 131.3, 75.9, 131.7, 76.1, 132.3);
    ctx.bezierCurveTo(76.4, 132.9, 76.1, 133.7, 75.4, 133.9);
    ctx.bezierCurveTo(74.7, 134.2, 74.0, 133.8, 73.8, 133.2);
    ctx.bezierCurveTo(73.5, 132.6, 73.9, 131.8, 74.5, 131.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(84.1, 129.9);
    ctx.bezierCurveTo(84.8, 129.7, 85.5, 130.0, 85.8, 130.6);
    ctx.bezierCurveTo(86.0, 131.3, 85.7, 132.0, 85.0, 132.2);
    ctx.bezierCurveTo(84.3, 132.5, 83.6, 132.2, 83.4, 131.5);
    ctx.bezierCurveTo(83.1, 130.9, 83.5, 130.2, 84.1, 129.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(92.9, 127.9);
    ctx.bezierCurveTo(93.6, 127.6, 94.3, 128.0, 94.6, 128.6);
    ctx.bezierCurveTo(94.8, 129.2, 94.5, 130.0, 93.8, 130.2);
    ctx.bezierCurveTo(93.2, 130.5, 92.4, 130.2, 92.2, 129.5);
    ctx.bezierCurveTo(91.9, 128.9, 92.3, 128.1, 92.9, 127.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(160.0, 374.2);
    ctx.bezierCurveTo(159.8, 374.2, 159.6, 374.2, 159.4, 374.2);
    ctx.bezierCurveTo(159.0, 374.2, 158.6, 373.8, 158.5, 373.3);
    ctx.lineTo(157.2, 363.2);
    ctx.bezierCurveTo(157.2, 363.0, 157.0, 362.8, 156.8, 362.7);
    ctx.bezierCurveTo(156.6, 362.6, 156.2, 362.5, 155.9, 362.4);
    ctx.bezierCurveTo(153.5, 361.8, 150.0, 360.7, 148.2, 355.2);
    ctx.bezierCurveTo(145.5, 347.1, 155.2, 340.0, 156.7, 339.2);
    ctx.bezierCurveTo(167.9, 333.6, 177.9, 332.8, 186.3, 337.0);
    ctx.bezierCurveTo(187.1, 337.3, 193.7, 340.8, 192.7, 348.2);
    ctx.bezierCurveTo(191.5, 356.3, 183.7, 362.5, 176.6, 364.2);
    ctx.bezierCurveTo(173.1, 365.0, 169.5, 365.0, 166.0, 364.2);
    ctx.lineTo(160.6, 373.6);
    ctx.bezierCurveTo(160.5, 373.9, 160.3, 374.1, 160.0, 374.2);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(164.2, 337.6);
    ctx.bezierCurveTo(161.9, 338.4, 159.6, 339.4, 157.3, 340.5);
    ctx.bezierCurveTo(157.3, 340.5, 147.0, 347.1, 149.6, 354.8);
    ctx.bezierCurveTo(151.2, 359.6, 154.2, 360.5, 156.4, 361.1);
    ctx.bezierCurveTo(156.8, 361.2, 157.1, 361.4, 157.3, 361.4);
    ctx.bezierCurveTo(158.1, 361.7, 158.6, 362.3, 158.7, 363.0);
    ctx.lineTo(159.9, 372.0);
    ctx.lineTo(164.7, 363.6);
    ctx.bezierCurveTo(165.0, 363.0, 165.7, 362.8, 166.3, 362.9);
    ctx.bezierCurveTo(169.6, 363.7, 173.0, 363.7, 176.2, 362.9);
    ctx.bezierCurveTo(182.8, 361.3, 190.0, 355.7, 191.0, 348.2);
    ctx.bezierCurveTo(191.9, 341.7, 186.1, 338.7, 185.4, 338.4);
    ctx.bezierCurveTo(179.2, 335.2, 172.1, 335.0, 164.2, 337.6);
    ctx.lineTo(164.2, 337.6);
    ctx.closePath();
    ctx.fillStyle = fillColor;
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(156.8, 352.3);
    ctx.bezierCurveTo(157.6, 352.1, 158.5, 352.5, 158.7, 353.2);
    ctx.bezierCurveTo(158.9, 353.9, 158.5, 354.7, 157.7, 355.0);
    ctx.bezierCurveTo(156.8, 355.3, 156.0, 354.9, 155.7, 354.2);
    ctx.bezierCurveTo(155.5, 353.4, 156.0, 352.6, 156.8, 352.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(169.8, 349.9);
    ctx.bezierCurveTo(170.6, 349.6, 171.5, 350.0, 171.7, 350.8);
    ctx.bezierCurveTo(172.0, 351.5, 171.5, 352.3, 170.7, 352.6);
    ctx.bezierCurveTo(169.9, 352.8, 169.0, 352.5, 168.8, 351.7);
    ctx.bezierCurveTo(168.5, 351.0, 169.0, 350.2, 169.8, 349.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(180.6, 347.8);
    ctx.bezierCurveTo(181.4, 347.5, 182.3, 347.9, 182.5, 348.7);
    ctx.bezierCurveTo(182.8, 349.4, 182.3, 350.2, 181.5, 350.5);
    ctx.bezierCurveTo(180.7, 350.7, 179.8, 350.4, 179.6, 349.6);
    ctx.bezierCurveTo(179.3, 348.9, 179.8, 348.1, 180.6, 347.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(160.2, 241.5);
    ctx.bezierCurveTo(160.0, 241.5, 159.9, 241.5, 159.7, 241.5);
    ctx.bezierCurveTo(159.3, 241.4, 158.9, 241.1, 158.9, 240.7);
    ctx.lineTo(157.7, 231.6);
    ctx.bezierCurveTo(157.6, 231.4, 157.5, 231.2, 157.3, 231.1);
    ctx.bezierCurveTo(157.1, 231.1, 156.8, 230.9, 156.5, 230.8);
    ctx.bezierCurveTo(153.1, 230.2, 150.5, 227.6, 149.6, 224.3);
    ctx.bezierCurveTo(147.2, 216.9, 155.7, 210.6, 157.0, 209.9);
    ctx.bezierCurveTo(166.9, 204.9, 175.7, 204.3, 183.2, 208.1);
    ctx.bezierCurveTo(183.9, 208.4, 189.7, 211.6, 188.9, 218.2);
    ctx.bezierCurveTo(187.9, 225.6, 181.0, 231.0, 174.8, 232.6);
    ctx.bezierCurveTo(171.7, 233.3, 168.5, 233.3, 165.4, 232.6);
    ctx.lineTo(160.7, 241.0);
    ctx.bezierCurveTo(160.6, 241.2, 160.4, 241.4, 160.2, 241.5);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(163.7, 208.5);
    ctx.bezierCurveTo(161.6, 209.2, 159.6, 210.1, 157.7, 211.1);
    ctx.bezierCurveTo(157.6, 211.1, 148.6, 217.0, 150.9, 223.9);
    ctx.bezierCurveTo(152.3, 228.3, 155.0, 229.1, 157.0, 229.7);
    ctx.bezierCurveTo(157.3, 229.8, 157.6, 229.9, 157.8, 229.9);
    ctx.bezierCurveTo(158.5, 230.1, 158.9, 230.7, 159.0, 231.4);
    ctx.lineTo(160.1, 239.5);
    ctx.lineTo(164.4, 231.9);
    ctx.bezierCurveTo(164.6, 231.5, 165.2, 231.2, 165.8, 231.3);
    ctx.bezierCurveTo(168.6, 232.1, 171.6, 232.1, 174.5, 231.4);
    ctx.bezierCurveTo(180.3, 230.0, 186.6, 225.0, 187.5, 218.2);
    ctx.bezierCurveTo(188.3, 212.4, 183.2, 209.6, 182.5, 209.3);
    ctx.bezierCurveTo(177.0, 206.4, 170.7, 206.2, 163.7, 208.5);
    ctx.lineTo(163.7, 208.5);
    ctx.closePath();
    ctx.fillStyle = fillColor;
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(158.3, 221.1);
    ctx.bezierCurveTo(159.1, 220.9, 159.8, 221.2, 160.0, 221.9);
    ctx.bezierCurveTo(160.3, 222.5, 159.8, 223.3, 159.1, 223.5);
    ctx.bezierCurveTo(158.4, 223.7, 157.6, 223.4, 157.4, 222.7);
    ctx.bezierCurveTo(157.2, 222.1, 157.6, 221.3, 158.3, 221.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(168.0, 220.4);
    ctx.bezierCurveTo(168.7, 220.1, 169.5, 220.5, 169.7, 221.1);
    ctx.bezierCurveTo(169.9, 221.8, 169.5, 222.5, 168.8, 222.8);
    ctx.bezierCurveTo(168.1, 223.0, 167.3, 222.7, 167.1, 222.0);
    ctx.bezierCurveTo(166.9, 221.3, 167.3, 220.6, 168.0, 220.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(178.3, 217.8);
    ctx.bezierCurveTo(179.0, 217.6, 179.8, 217.9, 180.0, 218.6);
    ctx.bezierCurveTo(180.2, 219.3, 179.8, 220.0, 179.1, 220.2);
    ctx.bezierCurveTo(178.4, 220.5, 177.6, 220.1, 177.4, 219.5);
    ctx.bezierCurveTo(177.2, 218.8, 177.6, 218.1, 178.3, 217.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(177.2, 276.1);
    ctx.bezierCurveTo(177.0, 276.2, 176.9, 276.2, 176.8, 276.1);
    ctx.bezierCurveTo(176.4, 276.1, 176.2, 275.8, 176.1, 275.5);
    ctx.lineTo(175.0, 267.9);
    ctx.bezierCurveTo(175.0, 267.7, 174.9, 267.6, 174.7, 267.5);
    ctx.bezierCurveTo(174.5, 267.5, 174.3, 267.3, 174.1, 267.2);
    ctx.bezierCurveTo(172.4, 266.7, 170.0, 265.8, 168.6, 261.7);
    ctx.bezierCurveTo(166.6, 255.5, 173.1, 250.4, 174.1, 249.8);
    ctx.bezierCurveTo(181.7, 245.8, 188.5, 245.5, 194.4, 248.8);
    ctx.bezierCurveTo(195.0, 249.1, 199.6, 251.9, 199.0, 257.4);
    ctx.bezierCurveTo(198.4, 263.5, 193.1, 267.9, 188.3, 269.0);
    ctx.bezierCurveTo(185.9, 269.6, 183.4, 269.5, 181.1, 268.8);
    ctx.lineTo(177.6, 275.7);
    ctx.bezierCurveTo(177.5, 275.9, 177.4, 276.0, 177.2, 276.1);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(179.2, 248.8);
    ctx.bezierCurveTo(177.6, 249.4, 176.1, 250.0, 174.6, 250.8);
    ctx.bezierCurveTo(174.5, 250.8, 167.6, 255.6, 169.6, 261.4);
    ctx.bezierCurveTo(170.8, 265.0, 172.9, 265.8, 174.4, 266.3);
    ctx.bezierCurveTo(174.7, 266.4, 174.9, 266.5, 175.1, 266.5);
    ctx.bezierCurveTo(175.6, 266.7, 176.0, 267.2, 176.1, 267.7);
    ctx.lineTo(177.1, 274.5);
    ctx.lineTo(180.2, 268.3);
    ctx.bezierCurveTo(180.4, 267.9, 180.9, 267.7, 181.3, 267.8);
    ctx.bezierCurveTo(183.5, 268.5, 185.9, 268.6, 188.1, 268.1);
    ctx.bezierCurveTo(192.6, 267.0, 197.4, 263.0, 198.0, 257.4);
    ctx.bezierCurveTo(198.2, 254.3, 196.7, 251.4, 194.0, 249.9);
    ctx.bezierCurveTo(189.6, 247.4, 184.6, 247.0, 179.2, 248.8);
    ctx.lineTo(179.2, 248.8);
    ctx.closePath();
    ctx.fillStyle = fillColor;
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(175.3, 259.2);
    ctx.bezierCurveTo(175.9, 259.0, 176.5, 259.3, 176.7, 259.8);
    ctx.bezierCurveTo(176.8, 260.4, 176.5, 261.0, 176.0, 261.2);
    ctx.bezierCurveTo(175.4, 261.4, 174.8, 261.1, 174.7, 260.5);
    ctx.bezierCurveTo(174.5, 260.0, 174.8, 259.4, 175.3, 259.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(183.4, 258.2);
    ctx.bezierCurveTo(184.0, 258.0, 184.6, 258.3, 184.7, 258.8);
    ctx.bezierCurveTo(184.9, 259.4, 184.6, 260.0, 184.1, 260.2);
    ctx.bezierCurveTo(183.5, 260.4, 182.9, 260.1, 182.7, 259.5);
    ctx.bezierCurveTo(182.5, 259.0, 182.8, 258.4, 183.4, 258.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(190.8, 256.8);
    ctx.bezierCurveTo(191.4, 256.7, 191.9, 257.0, 192.1, 257.5);
    ctx.bezierCurveTo(192.3, 258.1, 192.0, 258.7, 191.5, 258.8);
    ctx.bezierCurveTo(190.9, 259.0, 190.3, 258.7, 190.1, 258.2);
    ctx.bezierCurveTo(189.9, 257.6, 190.2, 257.0, 190.8, 256.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Path
    ctx.save();
    ctx.beginPath();
    ctx.moveTo(219.9, 401.7);
    ctx.bezierCurveTo(214.0, 398.4, 207.2, 398.7, 199.6, 402.7);
    ctx.bezierCurveTo(198.6, 403.3, 192.2, 408.2, 194.0, 414.2);
    ctx.lineTo(195.0, 414.2);
    ctx.lineTo(195.0, 414.2);
    ctx.bezierCurveTo(193.1, 408.4, 200.0, 403.7, 200.0, 403.7);
    ctx.bezierCurveTo(201.5, 402.9, 203.1, 402.2, 204.7, 401.7);
    ctx.bezierCurveTo(210.1, 399.9, 215.0, 400.2, 219.3, 402.7);
    ctx.bezierCurveTo(222.0, 404.2, 223.6, 407.1, 223.4, 410.2);
    ctx.bezierCurveTo(223.2, 411.6, 222.8, 412.9, 222.2, 414.2);
    ctx.lineTo(223.3, 414.2);
    ctx.bezierCurveTo(223.9, 412.9, 224.3, 411.6, 224.4, 410.2);
    ctx.bezierCurveTo(225.1, 404.8, 220.4, 402.0, 219.9, 401.7);
    ctx.closePath();
    ctx.fillStyle = fillColor;
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(200.8, 412.0);
    ctx.bezierCurveTo(201.4, 411.8, 202.0, 412.1, 202.1, 412.7);
    ctx.bezierCurveTo(202.3, 413.2, 202.0, 413.8, 201.5, 414.0);
    ctx.bezierCurveTo(200.9, 414.2, 200.3, 413.9, 200.1, 413.3);
    ctx.bezierCurveTo(199.9, 412.8, 200.3, 412.2, 200.8, 412.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(208.9, 411.0);
    ctx.bezierCurveTo(209.4, 410.8, 210.0, 411.1, 210.2, 411.7);
    ctx.bezierCurveTo(210.4, 412.2, 210.1, 412.8, 209.5, 413.0);
    ctx.bezierCurveTo(209.0, 413.2, 208.4, 412.9, 208.2, 412.3);
    ctx.bezierCurveTo(208.0, 411.8, 208.3, 411.2, 208.9, 411.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(216.3, 409.7);
    ctx.bezierCurveTo(216.8, 409.5, 217.4, 409.8, 217.6, 410.3);
    ctx.bezierCurveTo(217.8, 410.9, 217.5, 411.5, 216.9, 411.7);
    ctx.bezierCurveTo(216.4, 411.9, 215.8, 411.6, 215.6, 411.0);
    ctx.bezierCurveTo(215.4, 410.4, 215.7, 409.8, 216.3, 409.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.restore();
    ctx.beginPath();
    ctx.moveTo(222.2, 0.2);
    ctx.bezierCurveTo(220.4, 3.5, 217.2, 6.0, 213.5, 6.9);
    ctx.bezierCurveTo(211.3, 7.4, 208.9, 7.3, 206.7, 6.7);
    ctx.bezierCurveTo(206.3, 6.5, 205.9, 6.7, 205.7, 7.1);
    ctx.lineTo(202.5, 13.3);
    ctx.lineTo(201.5, 6.5);
    ctx.bezierCurveTo(201.4, 6.0, 201.0, 5.5, 200.5, 5.3);
    ctx.bezierCurveTo(200.3, 5.3, 200.1, 5.2, 199.9, 5.1);
    ctx.bezierCurveTo(198.3, 4.6, 196.2, 3.8, 195.0, 0.2);
    ctx.lineTo(194.0, 0.2);
    ctx.bezierCurveTo(194.0, 0.3, 194.0, 0.4, 194.1, 0.5);
    ctx.bezierCurveTo(195.4, 4.7, 197.9, 5.5, 199.6, 6.1);
    ctx.bezierCurveTo(199.8, 6.2, 200.0, 6.3, 200.2, 6.3);
    ctx.bezierCurveTo(200.4, 6.4, 200.5, 6.5, 200.5, 6.7);
    ctx.lineTo(201.6, 14.3);
    ctx.bezierCurveTo(201.6, 14.6, 201.9, 14.9, 202.3, 15.0);
    ctx.bezierCurveTo(202.4, 15.0, 202.5, 15.0, 202.7, 15.0);
    ctx.bezierCurveTo(202.8, 14.9, 203.0, 14.7, 203.1, 14.6);
    ctx.lineTo(206.6, 7.7);
    ctx.bezierCurveTo(208.9, 8.4, 211.4, 8.4, 213.8, 7.9);
    ctx.bezierCurveTo(218.0, 6.8, 221.4, 4.0, 223.4, 0.2);
    ctx.lineTo(222.2, 0.2);
    ctx.closePath();
    ctx.fillStyle = fillColor;
    ctx.fill();

    // layer1/Group

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(260.0, 223.5);
    ctx.bezierCurveTo(259.9, 223.5, 259.8, 223.5, 259.6, 223.5);
    ctx.bezierCurveTo(259.3, 223.5, 259.0, 223.2, 259.0, 222.9);
    ctx.lineTo(258.0, 215.7);
    ctx.bezierCurveTo(257.9, 215.5, 257.8, 215.4, 257.7, 215.3);
    ctx.bezierCurveTo(257.5, 215.3, 257.3, 215.1, 257.1, 215.1);
    ctx.bezierCurveTo(255.5, 214.5, 253.1, 213.7, 251.8, 209.7);
    ctx.bezierCurveTo(249.9, 203.9, 256.1, 199.0, 257.1, 198.5);
    ctx.bezierCurveTo(264.3, 194.7, 270.8, 194.4, 276.4, 197.6);
    ctx.bezierCurveTo(276.9, 197.8, 281.3, 200.5, 280.8, 205.7);
    ctx.bezierCurveTo(280.2, 211.5, 275.2, 215.7, 270.6, 216.8);
    ctx.bezierCurveTo(268.3, 217.3, 266.0, 217.2, 263.7, 216.6);
    ctx.lineTo(260.4, 223.1);
    ctx.bezierCurveTo(260.3, 223.3, 260.2, 223.4, 260.0, 223.5);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(262.0, 197.5);
    ctx.bezierCurveTo(260.5, 198.0, 259.0, 198.6, 257.6, 199.4);
    ctx.bezierCurveTo(257.6, 199.4, 251.0, 203.9, 252.8, 209.4);
    ctx.bezierCurveTo(253.9, 212.9, 255.9, 213.6, 257.4, 214.0);
    ctx.bezierCurveTo(257.6, 214.1, 257.8, 214.2, 258.0, 214.3);
    ctx.bezierCurveTo(258.5, 214.5, 258.9, 214.9, 258.9, 215.4);
    ctx.lineTo(259.9, 221.9);
    ctx.lineTo(262.9, 216.0);
    ctx.bezierCurveTo(263.1, 215.6, 263.5, 215.4, 263.9, 215.5);
    ctx.bezierCurveTo(266.0, 216.2, 268.3, 216.3, 270.4, 215.8);
    ctx.bezierCurveTo(274.7, 214.7, 279.3, 210.9, 279.8, 205.6);
    ctx.bezierCurveTo(280.1, 202.7, 278.5, 199.9, 276.0, 198.5);
    ctx.bezierCurveTo(271.8, 196.1, 267.1, 195.8, 261.9, 197.5);
    ctx.lineTo(262.0, 197.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(258.2, 207.4);
    ctx.bezierCurveTo(258.8, 207.2, 259.3, 207.5, 259.5, 208.0);
    ctx.bezierCurveTo(259.7, 208.5, 259.4, 209.1, 258.8, 209.3);
    ctx.bezierCurveTo(258.3, 209.5, 257.7, 209.2, 257.6, 208.7);
    ctx.bezierCurveTo(257.4, 208.1, 257.7, 207.6, 258.2, 207.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(265.9, 206.4);
    ctx.bezierCurveTo(266.4, 206.3, 267.0, 206.5, 267.2, 207.1);
    ctx.bezierCurveTo(267.3, 207.6, 267.1, 208.2, 266.5, 208.3);
    ctx.bezierCurveTo(266.0, 208.5, 265.4, 208.2, 265.3, 207.7);
    ctx.bezierCurveTo(265.1, 207.2, 265.4, 206.6, 265.9, 206.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(272.9, 205.2);
    ctx.bezierCurveTo(273.5, 205.0, 274.0, 205.3, 274.2, 205.8);
    ctx.bezierCurveTo(274.4, 206.3, 274.1, 206.9, 273.6, 207.1);
    ctx.bezierCurveTo(273.0, 207.2, 272.5, 207.0, 272.3, 206.4);
    ctx.bezierCurveTo(272.1, 205.9, 272.4, 205.3, 272.9, 205.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(36.5, 281.4);
    ctx.bezierCurveTo(36.3, 281.4, 36.2, 281.4, 36.1, 281.4);
    ctx.bezierCurveTo(35.7, 281.3, 35.5, 281.1, 35.4, 280.7);
    ctx.lineTo(34.3, 273.3);
    ctx.bezierCurveTo(34.3, 273.2, 34.2, 273.0, 34.0, 272.9);
    ctx.bezierCurveTo(33.9, 272.9, 33.7, 272.8, 33.4, 272.7);
    ctx.bezierCurveTo(31.9, 272.1, 29.4, 271.3, 28.1, 267.2);
    ctx.bezierCurveTo(26.1, 261.2, 32.4, 256.3, 33.4, 255.7);
    ctx.bezierCurveTo(40.6, 251.9, 47.2, 251.6, 52.9, 254.9);
    ctx.bezierCurveTo(53.4, 255.1, 57.9, 257.9, 57.4, 263.2);
    ctx.bezierCurveTo(56.8, 269.2, 51.8, 273.4, 47.1, 274.5);
    ctx.bezierCurveTo(44.8, 275.1, 42.4, 275.0, 40.1, 274.3);
    ctx.lineTo(36.8, 281.0);
    ctx.bezierCurveTo(36.7, 281.2, 36.6, 281.3, 36.5, 281.4);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(38.3, 254.8);
    ctx.bezierCurveTo(36.8, 255.3, 35.3, 255.9, 33.8, 256.7);
    ctx.bezierCurveTo(33.8, 256.7, 27.2, 261.3, 29.0, 267.0);
    ctx.bezierCurveTo(30.2, 270.5, 32.2, 271.3, 33.8, 271.8);
    ctx.bezierCurveTo(34.0, 271.8, 34.2, 271.9, 34.4, 272.0);
    ctx.bezierCurveTo(34.9, 272.2, 35.2, 272.7, 35.3, 273.2);
    ctx.lineTo(36.3, 279.8);
    ctx.lineTo(39.3, 273.8);
    ctx.bezierCurveTo(39.5, 273.5, 39.9, 273.3, 40.3, 273.4);
    ctx.bezierCurveTo(42.4, 274.1, 44.7, 274.2, 46.8, 273.7);
    ctx.bezierCurveTo(51.2, 272.6, 55.8, 268.7, 56.3, 263.3);
    ctx.bezierCurveTo(56.5, 260.3, 55.0, 257.4, 52.4, 255.9);
    ctx.bezierCurveTo(48.2, 253.4, 43.5, 253.1, 38.3, 254.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(34.6, 264.9);
    ctx.bezierCurveTo(35.1, 264.7, 35.7, 265.0, 35.9, 265.5);
    ctx.bezierCurveTo(36.1, 266.1, 35.8, 266.6, 35.2, 266.8);
    ctx.bezierCurveTo(34.7, 267.0, 34.1, 266.7, 33.9, 266.2);
    ctx.bezierCurveTo(33.8, 265.6, 34.1, 265.0, 34.6, 264.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(42.3, 263.9);
    ctx.bezierCurveTo(42.9, 263.8, 43.5, 264.0, 43.6, 264.6);
    ctx.bezierCurveTo(43.8, 265.1, 43.5, 265.7, 43.0, 265.9);
    ctx.bezierCurveTo(42.5, 266.1, 41.9, 265.8, 41.7, 265.2);
    ctx.bezierCurveTo(41.5, 264.7, 41.8, 264.1, 42.3, 263.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(48.5, 263.0);
    ctx.bezierCurveTo(49.0, 262.8, 49.6, 263.1, 49.8, 263.6);
    ctx.bezierCurveTo(50.0, 264.2, 49.7, 264.8, 49.1, 264.9);
    ctx.bezierCurveTo(48.6, 265.1, 48.0, 264.8, 47.8, 264.3);
    ctx.bezierCurveTo(47.7, 263.7, 48.0, 263.1, 48.5, 263.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(23.0, 231.0);
    ctx.bezierCurveTo(22.9, 231.0, 22.8, 231.0, 22.6, 231.0);
    ctx.bezierCurveTo(22.3, 231.0, 22.0, 230.7, 22.0, 230.3);
    ctx.lineTo(20.9, 222.9);
    ctx.bezierCurveTo(20.9, 222.8, 20.7, 222.6, 20.6, 222.5);
    ctx.bezierCurveTo(20.4, 222.5, 20.2, 222.4, 20.0, 222.3);
    ctx.bezierCurveTo(18.4, 221.8, 16.0, 220.9, 14.7, 216.8);
    ctx.bezierCurveTo(12.7, 210.8, 18.9, 205.8, 19.9, 205.3);
    ctx.bezierCurveTo(27.2, 201.5, 33.7, 201.2, 39.4, 204.5);
    ctx.bezierCurveTo(40.0, 204.7, 44.4, 207.5, 43.9, 212.8);
    ctx.bezierCurveTo(43.3, 218.8, 38.3, 223.0, 33.7, 224.1);
    ctx.bezierCurveTo(31.4, 224.7, 29.0, 224.6, 26.7, 223.9);
    ctx.lineTo(23.4, 230.6);
    ctx.bezierCurveTo(23.3, 230.8, 23.2, 230.9, 23.0, 231.0);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(24.8, 204.4);
    ctx.bezierCurveTo(23.3, 204.9, 21.8, 205.5, 20.4, 206.3);
    ctx.bezierCurveTo(20.3, 206.3, 13.7, 210.9, 15.6, 216.6);
    ctx.bezierCurveTo(16.8, 220.1, 18.8, 220.9, 20.3, 221.4);
    ctx.bezierCurveTo(20.5, 221.4, 20.7, 221.5, 20.9, 221.6);
    ctx.bezierCurveTo(21.4, 221.8, 21.8, 222.3, 21.9, 222.8);
    ctx.lineTo(22.9, 229.4);
    ctx.lineTo(25.9, 223.4);
    ctx.bezierCurveTo(26.0, 223.1, 26.5, 222.9, 26.9, 223.0);
    ctx.bezierCurveTo(29.0, 223.7, 31.2, 223.7, 33.4, 223.3);
    ctx.bezierCurveTo(37.7, 222.3, 42.3, 218.3, 42.8, 212.9);
    ctx.bezierCurveTo(43.1, 209.9, 41.6, 207.0, 39.0, 205.5);
    ctx.bezierCurveTo(34.8, 203.0, 30.0, 202.7, 24.9, 204.4);
    ctx.lineTo(24.8, 204.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(21.2, 214.5);
    ctx.bezierCurveTo(21.7, 214.3, 22.3, 214.6, 22.5, 215.1);
    ctx.bezierCurveTo(22.6, 215.7, 22.3, 216.2, 21.8, 216.4);
    ctx.bezierCurveTo(21.3, 216.6, 20.7, 216.3, 20.5, 215.8);
    ctx.bezierCurveTo(20.3, 215.2, 20.6, 214.6, 21.2, 214.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(28.9, 213.5);
    ctx.bezierCurveTo(29.4, 213.4, 30.0, 213.6, 30.2, 214.2);
    ctx.bezierCurveTo(30.4, 214.7, 30.1, 215.3, 29.6, 215.5);
    ctx.bezierCurveTo(29.0, 215.7, 28.4, 215.4, 28.3, 214.8);
    ctx.bezierCurveTo(28.1, 214.3, 28.4, 213.7, 28.9, 213.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(35.2, 212.5);
    ctx.bezierCurveTo(35.8, 212.3, 36.4, 212.6, 36.5, 213.2);
    ctx.bezierCurveTo(36.7, 213.7, 36.4, 214.3, 35.9, 214.5);
    ctx.bezierCurveTo(35.4, 214.6, 34.8, 214.3, 34.6, 213.8);
    ctx.bezierCurveTo(34.4, 213.3, 34.7, 212.7, 35.2, 212.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(32.5, 145.5);
    ctx.bezierCurveTo(32.4, 145.5, 32.3, 145.5, 32.2, 145.5);
    ctx.bezierCurveTo(31.8, 145.4, 31.6, 145.2, 31.6, 144.9);
    ctx.lineTo(30.6, 138.0);
    ctx.bezierCurveTo(30.5, 137.8, 30.4, 137.7, 30.3, 137.6);
    ctx.bezierCurveTo(30.1, 137.6, 30.0, 137.5, 29.7, 137.4);
    ctx.bezierCurveTo(28.3, 136.9, 26.1, 136.1, 24.9, 132.3);
    ctx.bezierCurveTo(23.0, 126.7, 28.7, 122.2, 29.6, 121.7);
    ctx.bezierCurveTo(36.2, 118.2, 42.2, 117.9, 47.4, 121.0);
    ctx.bezierCurveTo(50.1, 122.6, 51.7, 125.6, 51.5, 128.8);
    ctx.bezierCurveTo(51.0, 134.3, 46.5, 138.2, 42.2, 139.2);
    ctx.bezierCurveTo(40.1, 139.7, 38.0, 139.6, 35.9, 138.9);
    ctx.lineTo(32.9, 145.1);
    ctx.bezierCurveTo(32.8, 145.3, 32.7, 145.4, 32.5, 145.5);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(34.0, 120.8);
    ctx.bezierCurveTo(32.6, 121.3, 31.3, 121.9, 30.0, 122.6);
    ctx.bezierCurveTo(30.0, 122.6, 24.0, 126.8, 25.7, 132.0);
    ctx.bezierCurveTo(26.8, 135.4, 28.6, 136.0, 30.0, 136.5);
    ctx.bezierCurveTo(30.2, 136.6, 30.4, 136.7, 30.6, 136.7);
    ctx.bezierCurveTo(31.0, 136.9, 31.4, 137.4, 31.4, 137.9);
    ctx.lineTo(32.4, 144.0);
    ctx.lineTo(35.1, 138.4);
    ctx.bezierCurveTo(35.3, 138.1, 35.7, 137.9, 36.1, 138.0);
    ctx.bezierCurveTo(38.0, 138.7, 40.1, 138.8, 42.1, 138.3);
    ctx.bezierCurveTo(46.0, 137.3, 50.2, 133.8, 50.6, 128.7);
    ctx.bezierCurveTo(50.8, 126.0, 49.4, 123.3, 47.0, 121.9);
    ctx.bezierCurveTo(43.0, 119.6, 38.7, 119.3, 34.0, 120.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(30.7, 130.1);
    ctx.bezierCurveTo(31.2, 130.0, 31.7, 130.3, 31.9, 130.8);
    ctx.bezierCurveTo(32.0, 131.3, 31.8, 131.8, 31.3, 132.0);
    ctx.bezierCurveTo(30.8, 132.1, 30.3, 131.8, 30.1, 131.3);
    ctx.bezierCurveTo(29.9, 130.8, 30.2, 130.3, 30.7, 130.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(37.8, 129.3);
    ctx.bezierCurveTo(38.2, 129.2, 38.8, 129.4, 38.9, 129.9);
    ctx.bezierCurveTo(39.1, 130.4, 38.8, 131.0, 38.4, 131.1);
    ctx.bezierCurveTo(37.9, 131.3, 37.3, 131.0, 37.2, 130.5);
    ctx.bezierCurveTo(37.0, 130.0, 37.3, 129.5, 37.8, 129.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(44.2, 128.2);
    ctx.bezierCurveTo(44.7, 128.0, 45.2, 128.3, 45.4, 128.8);
    ctx.bezierCurveTo(45.6, 129.3, 45.3, 129.9, 44.8, 130.0);
    ctx.bezierCurveTo(44.3, 130.2, 43.8, 129.9, 43.6, 129.4);
    ctx.bezierCurveTo(43.5, 128.9, 43.7, 128.3, 44.2, 128.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(75.2, 56.6);
    ctx.bezierCurveTo(75.1, 56.6, 75.0, 56.6, 74.9, 56.6);
    ctx.bezierCurveTo(74.6, 56.6, 74.4, 56.4, 74.3, 56.0);
    ctx.lineTo(73.4, 49.6);
    ctx.bezierCurveTo(73.4, 49.4, 73.3, 49.3, 73.2, 49.2);
    ctx.bezierCurveTo(73.0, 49.2, 72.8, 49.1, 72.6, 49.0);
    ctx.bezierCurveTo(70.3, 48.4, 68.4, 46.6, 67.8, 44.3);
    ctx.bezierCurveTo(66.1, 39.0, 71.8, 34.6, 72.7, 34.1);
    ctx.bezierCurveTo(79.4, 30.7, 85.3, 30.3, 90.5, 33.1);
    ctx.bezierCurveTo(90.9, 33.3, 95.0, 35.7, 94.5, 40.4);
    ctx.bezierCurveTo(93.9, 45.6, 89.3, 49.4, 85.1, 50.4);
    ctx.bezierCurveTo(83.0, 50.9, 80.8, 50.9, 78.7, 50.3);
    ctx.lineTo(75.7, 56.2);
    ctx.bezierCurveTo(75.6, 56.4, 75.4, 56.5, 75.2, 56.6);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(77.2, 33.2);
    ctx.bezierCurveTo(75.8, 33.7, 74.5, 34.2, 73.2, 34.9);
    ctx.bezierCurveTo(73.2, 34.9, 67.0, 39.0, 68.7, 44.0);
    ctx.bezierCurveTo(69.2, 46.1, 70.8, 47.7, 72.9, 48.2);
    ctx.bezierCurveTo(73.1, 48.3, 73.3, 48.4, 73.5, 48.4);
    ctx.bezierCurveTo(73.9, 48.6, 74.2, 49.0, 74.3, 49.5);
    ctx.lineTo(75.1, 55.2);
    ctx.lineTo(77.9, 49.9);
    ctx.bezierCurveTo(78.1, 49.5, 78.5, 49.3, 78.9, 49.5);
    ctx.bezierCurveTo(80.8, 50.0, 82.8, 50.1, 84.8, 49.6);
    ctx.bezierCurveTo(88.8, 48.6, 93.0, 45.2, 93.5, 40.4);
    ctx.bezierCurveTo(93.7, 37.7, 92.3, 35.2, 90.0, 34.0);
    ctx.bezierCurveTo(86.2, 31.9, 81.9, 31.6, 77.2, 33.2);
    ctx.lineTo(77.2, 33.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(73.7, 42.1);
    ctx.bezierCurveTo(74.2, 41.9, 74.7, 42.2, 74.9, 42.7);
    ctx.bezierCurveTo(75.1, 43.1, 74.8, 43.6, 74.3, 43.8);
    ctx.bezierCurveTo(73.8, 44.0, 73.3, 43.7, 73.1, 43.2);
    ctx.bezierCurveTo(73.0, 42.8, 73.3, 42.3, 73.7, 42.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(80.8, 41.2);
    ctx.bezierCurveTo(81.3, 41.0, 81.8, 41.3, 82.0, 41.7);
    ctx.bezierCurveTo(82.1, 42.2, 81.8, 42.7, 81.4, 42.9);
    ctx.bezierCurveTo(80.9, 43.1, 80.3, 42.8, 80.2, 42.3);
    ctx.bezierCurveTo(80.0, 41.9, 80.3, 41.3, 80.8, 41.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(87.3, 40.0);
    ctx.bezierCurveTo(87.7, 39.8, 88.3, 40.1, 88.4, 40.6);
    ctx.bezierCurveTo(88.6, 41.0, 88.3, 41.6, 87.8, 41.7);
    ctx.bezierCurveTo(87.3, 41.9, 86.8, 41.6, 86.7, 41.2);
    ctx.bezierCurveTo(86.5, 40.7, 86.8, 40.2, 87.3, 40.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(95.9, 168.6);
    ctx.bezierCurveTo(95.8, 168.6, 95.7, 168.6, 95.6, 168.6);
    ctx.bezierCurveTo(95.3, 168.5, 95.1, 168.3, 95.0, 168.0);
    ctx.lineTo(94.0, 161.3);
    ctx.bezierCurveTo(94.0, 161.1, 93.9, 161.0, 93.8, 160.9);
    ctx.bezierCurveTo(93.6, 160.9, 93.4, 160.8, 93.2, 160.7);
    ctx.bezierCurveTo(91.8, 160.2, 89.8, 159.4, 88.6, 155.7);
    ctx.bezierCurveTo(86.8, 150.3, 92.1, 145.9, 92.9, 145.5);
    ctx.bezierCurveTo(99.1, 142.1, 104.7, 142.0, 109.7, 145.0);
    ctx.bezierCurveTo(112.3, 146.6, 113.8, 149.5, 113.7, 152.6);
    ctx.bezierCurveTo(113.2, 157.4, 109.8, 161.4, 105.1, 162.6);
    ctx.bezierCurveTo(103.1, 163.0, 101.0, 162.9, 99.1, 162.2);
    ctx.lineTo(96.3, 168.2);
    ctx.bezierCurveTo(96.2, 168.4, 96.1, 168.5, 95.9, 168.6);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(97.1, 144.7);
    ctx.bezierCurveTo(95.8, 145.1, 94.5, 145.7, 93.3, 146.3);
    ctx.bezierCurveTo(93.3, 146.3, 87.6, 150.3, 89.3, 155.5);
    ctx.bezierCurveTo(90.4, 158.7, 92.1, 159.4, 93.4, 159.9);
    ctx.bezierCurveTo(93.6, 159.9, 93.8, 160.0, 93.9, 160.1);
    ctx.bezierCurveTo(94.4, 160.3, 94.7, 160.7, 94.7, 161.2);
    ctx.lineTo(95.7, 167.2);
    ctx.lineTo(98.2, 161.8);
    ctx.bezierCurveTo(98.4, 161.5, 98.8, 161.3, 99.1, 161.4);
    ctx.bezierCurveTo(100.9, 162.0, 102.9, 162.2, 104.7, 161.8);
    ctx.bezierCurveTo(109.1, 160.7, 112.3, 157.0, 112.7, 152.5);
    ctx.bezierCurveTo(112.9, 149.9, 111.5, 147.3, 109.2, 145.9);
    ctx.bezierCurveTo(105.6, 143.6, 101.1, 143.2, 97.1, 144.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(93.5, 154.1);
    ctx.bezierCurveTo(94.0, 153.9, 94.5, 154.2, 94.7, 154.7);
    ctx.bezierCurveTo(94.8, 155.2, 94.6, 155.7, 94.1, 155.8);
    ctx.bezierCurveTo(93.7, 156.0, 93.2, 155.7, 93.0, 155.2);
    ctx.bezierCurveTo(92.8, 154.7, 93.1, 154.2, 93.5, 154.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(100.7, 152.9);
    ctx.bezierCurveTo(101.2, 152.8, 101.7, 153.1, 101.8, 153.6);
    ctx.bezierCurveTo(102.0, 154.0, 101.7, 154.6, 101.3, 154.7);
    ctx.bezierCurveTo(100.8, 154.9, 100.3, 154.6, 100.2, 154.1);
    ctx.bezierCurveTo(100.0, 153.6, 100.2, 153.1, 100.7, 152.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(106.8, 151.9);
    ctx.bezierCurveTo(107.2, 151.8, 107.7, 152.0, 107.9, 152.5);
    ctx.bezierCurveTo(108.1, 153.0, 107.8, 153.5, 107.4, 153.7);
    ctx.bezierCurveTo(106.9, 153.8, 106.4, 153.6, 106.2, 153.1);
    ctx.bezierCurveTo(106.1, 152.6, 106.3, 152.1, 106.8, 151.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(54.0, 215.6);
    ctx.bezierCurveTo(53.9, 215.7, 53.8, 215.7, 53.7, 215.6);
    ctx.bezierCurveTo(53.4, 215.6, 53.2, 215.4, 53.1, 215.1);
    ctx.lineTo(52.0, 208.4);
    ctx.bezierCurveTo(52.0, 208.2, 51.9, 208.1, 51.8, 208.0);
    ctx.bezierCurveTo(51.6, 208.0, 51.4, 207.9, 51.2, 207.8);
    ctx.bezierCurveTo(49.9, 207.3, 47.8, 206.5, 46.6, 202.8);
    ctx.bezierCurveTo(44.8, 197.4, 50.1, 193.0, 50.9, 192.5);
    ctx.bezierCurveTo(57.1, 189.2, 62.7, 189.0, 67.7, 192.1);
    ctx.bezierCurveTo(70.3, 193.7, 71.8, 196.6, 71.7, 199.6);
    ctx.bezierCurveTo(71.2, 204.5, 67.7, 208.5, 63.0, 209.6);
    ctx.bezierCurveTo(61.1, 210.1, 59.0, 210.0, 57.0, 209.3);
    ctx.lineTo(54.3, 215.3);
    ctx.bezierCurveTo(54.2, 215.4, 54.1, 215.6, 54.0, 215.6);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(55.2, 191.7);
    ctx.bezierCurveTo(53.9, 192.2, 52.6, 192.7, 51.4, 193.4);
    ctx.bezierCurveTo(51.4, 193.4, 45.7, 197.4, 47.4, 202.5);
    ctx.bezierCurveTo(48.4, 205.8, 50.2, 206.5, 51.5, 206.9);
    ctx.bezierCurveTo(51.7, 207.0, 51.9, 207.1, 52.0, 207.2);
    ctx.bezierCurveTo(52.5, 207.4, 52.8, 207.8, 52.8, 208.3);
    ctx.lineTo(53.8, 214.3);
    ctx.lineTo(56.3, 208.9);
    ctx.bezierCurveTo(56.5, 208.5, 56.9, 208.4, 57.2, 208.5);
    ctx.bezierCurveTo(59.0, 209.1, 61.0, 209.2, 62.8, 208.8);
    ctx.bezierCurveTo(67.2, 207.8, 70.4, 204.1, 70.8, 199.6);
    ctx.bezierCurveTo(71.0, 196.9, 69.6, 194.4, 67.3, 193.0);
    ctx.bezierCurveTo(63.7, 190.7, 59.2, 190.2, 55.2, 191.7);
    ctx.lineTo(55.2, 191.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(51.4, 201.0);
    ctx.bezierCurveTo(51.9, 200.9, 52.4, 201.2, 52.5, 201.6);
    ctx.bezierCurveTo(52.7, 202.1, 52.4, 202.6, 52.0, 202.8);
    ctx.bezierCurveTo(51.5, 202.9, 51.0, 202.7, 50.9, 202.2);
    ctx.bezierCurveTo(50.7, 201.7, 51.0, 201.2, 51.4, 201.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(58.8, 200.0);
    ctx.bezierCurveTo(59.2, 199.9, 59.7, 200.1, 59.9, 200.6);
    ctx.bezierCurveTo(60.0, 201.1, 59.8, 201.6, 59.3, 201.8);
    ctx.bezierCurveTo(58.9, 201.9, 58.4, 201.7, 58.2, 201.2);
    ctx.bezierCurveTo(58.1, 200.7, 58.3, 200.2, 58.8, 200.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(64.8, 199.0);
    ctx.bezierCurveTo(65.3, 198.8, 65.8, 199.1, 66.0, 199.6);
    ctx.bezierCurveTo(66.1, 200.1, 65.9, 200.6, 65.4, 200.8);
    ctx.bezierCurveTo(65.0, 200.9, 64.5, 200.6, 64.3, 200.1);
    ctx.bezierCurveTo(64.1, 199.7, 64.4, 199.1, 64.8, 199.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(202.0, 124.2);
    ctx.bezierCurveTo(201.9, 124.2, 201.8, 124.2, 201.7, 124.2);
    ctx.bezierCurveTo(201.4, 124.2, 201.2, 123.9, 201.1, 123.6);
    ctx.lineTo(200.1, 116.9);
    ctx.bezierCurveTo(200.0, 116.8, 199.9, 116.7, 199.8, 116.6);
    ctx.bezierCurveTo(199.6, 116.5, 199.5, 116.4, 199.3, 116.4);
    ctx.bezierCurveTo(197.9, 115.8, 195.8, 115.0, 194.6, 111.4);
    ctx.bezierCurveTo(192.8, 105.9, 198.1, 101.6, 199.0, 101.1);
    ctx.bezierCurveTo(205.1, 97.8, 210.8, 97.6, 215.7, 100.6);
    ctx.bezierCurveTo(218.3, 102.2, 219.9, 105.1, 219.7, 108.2);
    ctx.bezierCurveTo(219.3, 113.0, 215.8, 117.0, 211.1, 118.2);
    ctx.bezierCurveTo(209.1, 118.6, 207.0, 118.5, 205.1, 117.9);
    ctx.lineTo(202.3, 123.9);
    ctx.bezierCurveTo(202.3, 124.0, 202.2, 124.1, 202.0, 124.2);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(203.2, 100.3);
    ctx.bezierCurveTo(201.9, 100.7, 200.6, 101.3, 199.4, 102.0);
    ctx.bezierCurveTo(199.4, 102.0, 193.7, 106.0, 195.4, 111.1);
    ctx.bezierCurveTo(196.5, 114.3, 198.2, 115.0, 199.5, 115.5);
    ctx.bezierCurveTo(199.7, 115.6, 199.9, 115.7, 200.1, 115.7);
    ctx.bezierCurveTo(200.5, 115.9, 200.8, 116.3, 200.9, 116.8);
    ctx.lineTo(201.9, 122.8);
    ctx.lineTo(204.4, 117.4);
    ctx.bezierCurveTo(204.5, 117.1, 204.9, 116.9, 205.3, 117.0);
    ctx.bezierCurveTo(207.1, 117.7, 209.0, 117.8, 210.9, 117.4);
    ctx.bezierCurveTo(215.2, 116.3, 218.4, 112.6, 218.9, 108.2);
    ctx.bezierCurveTo(219.0, 105.5, 217.7, 103.0, 215.4, 101.5);
    ctx.bezierCurveTo(211.7, 99.2, 207.2, 98.8, 203.2, 100.3);
    ctx.lineTo(203.2, 100.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(199.8, 110.1);
    ctx.bezierCurveTo(200.3, 110.0, 200.8, 110.2, 201.0, 110.7);
    ctx.bezierCurveTo(201.1, 111.2, 200.9, 111.7, 200.4, 111.9);
    ctx.bezierCurveTo(200.0, 112.0, 199.5, 111.7, 199.3, 111.3);
    ctx.bezierCurveTo(199.2, 110.8, 199.4, 110.3, 199.8, 110.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(206.8, 108.6);
    ctx.bezierCurveTo(207.3, 108.5, 207.8, 108.7, 207.9, 109.2);
    ctx.bezierCurveTo(208.1, 109.7, 207.8, 110.2, 207.4, 110.4);
    ctx.bezierCurveTo(206.9, 110.5, 206.4, 110.2, 206.3, 109.8);
    ctx.bezierCurveTo(206.1, 109.3, 206.3, 108.8, 206.8, 108.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(212.9, 107.6);
    ctx.bezierCurveTo(213.3, 107.4, 213.8, 107.7, 214.0, 108.2);
    ctx.bezierCurveTo(214.2, 108.7, 213.9, 109.2, 213.5, 109.3);
    ctx.bezierCurveTo(213.0, 109.5, 212.5, 109.2, 212.3, 108.7);
    ctx.bezierCurveTo(212.2, 108.2, 212.4, 107.7, 212.9, 107.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(221.1, 95.3);
    ctx.bezierCurveTo(221.0, 95.4, 220.9, 95.4, 220.8, 95.3);
    ctx.bezierCurveTo(220.5, 95.3, 220.3, 95.0, 220.3, 94.7);
    ctx.lineTo(219.2, 88.1);
    ctx.bezierCurveTo(219.2, 87.9, 219.1, 87.8, 218.9, 87.7);
    ctx.bezierCurveTo(218.8, 87.7, 218.6, 87.6, 218.4, 87.5);
    ctx.bezierCurveTo(217.1, 87.0, 215.0, 86.2, 213.8, 82.5);
    ctx.bezierCurveTo(212.0, 77.0, 217.2, 72.7, 218.1, 72.2);
    ctx.bezierCurveTo(224.3, 68.9, 229.9, 68.7, 234.9, 71.7);
    ctx.bezierCurveTo(237.5, 73.4, 239.0, 76.3, 238.9, 79.3);
    ctx.bezierCurveTo(238.4, 84.1, 234.9, 88.2, 230.2, 89.3);
    ctx.bezierCurveTo(228.3, 89.8, 226.2, 89.6, 224.2, 89.0);
    ctx.lineTo(221.5, 95.0);
    ctx.bezierCurveTo(221.4, 95.2, 221.3, 95.3, 221.1, 95.3);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(222.3, 71.4);
    ctx.bezierCurveTo(221.0, 71.9, 219.7, 72.4, 218.5, 73.1);
    ctx.bezierCurveTo(218.5, 73.1, 212.9, 77.1, 214.5, 82.3);
    ctx.bezierCurveTo(215.6, 85.5, 217.3, 86.2, 218.6, 86.6);
    ctx.bezierCurveTo(218.8, 86.7, 219.0, 86.8, 219.2, 86.9);
    ctx.bezierCurveTo(219.6, 87.1, 219.9, 87.5, 220.0, 88.0);
    ctx.lineTo(221.0, 94.0);
    ctx.lineTo(223.5, 88.6);
    ctx.bezierCurveTo(223.6, 88.2, 224.0, 88.1, 224.4, 88.2);
    ctx.bezierCurveTo(226.2, 88.8, 228.1, 88.9, 230.0, 88.5);
    ctx.bezierCurveTo(234.3, 87.5, 237.5, 83.8, 238.0, 79.3);
    ctx.bezierCurveTo(238.1, 76.6, 236.8, 74.1, 234.5, 72.7);
    ctx.bezierCurveTo(230.8, 70.4, 226.3, 69.9, 222.3, 71.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(219.1, 81.3);
    ctx.bezierCurveTo(219.6, 81.2, 220.1, 81.4, 220.2, 81.9);
    ctx.bezierCurveTo(220.4, 82.4, 220.1, 82.9, 219.7, 83.1);
    ctx.bezierCurveTo(219.2, 83.2, 218.7, 82.9, 218.6, 82.5);
    ctx.bezierCurveTo(218.4, 82.0, 218.6, 81.4, 219.1, 81.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(225.8, 80.6);
    ctx.bezierCurveTo(226.2, 80.4, 226.7, 80.7, 226.9, 81.2);
    ctx.bezierCurveTo(227.0, 81.7, 226.8, 82.2, 226.3, 82.4);
    ctx.bezierCurveTo(225.9, 82.5, 225.4, 82.2, 225.2, 81.7);
    ctx.bezierCurveTo(225.1, 81.2, 225.3, 80.7, 225.8, 80.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(232.0, 78.7);
    ctx.bezierCurveTo(232.5, 78.6, 233.0, 78.8, 233.1, 79.3);
    ctx.bezierCurveTo(233.3, 79.8, 233.1, 80.3, 232.6, 80.5);
    ctx.bezierCurveTo(232.2, 80.6, 231.6, 80.3, 231.5, 79.9);
    ctx.bezierCurveTo(231.3, 79.4, 231.6, 78.9, 232.0, 78.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(176.0, 36.4);
    ctx.bezierCurveTo(175.9, 36.4, 175.8, 36.4, 175.7, 36.4);
    ctx.bezierCurveTo(175.4, 36.4, 175.2, 36.1, 175.1, 35.8);
    ctx.lineTo(174.1, 29.1);
    ctx.bezierCurveTo(174.1, 29.0, 174.0, 28.9, 173.9, 28.8);
    ctx.bezierCurveTo(173.7, 28.8, 173.5, 28.6, 173.3, 28.6);
    ctx.bezierCurveTo(172.0, 28.0, 169.9, 27.2, 168.7, 23.6);
    ctx.bezierCurveTo(166.9, 18.1, 172.2, 13.8, 173.0, 13.3);
    ctx.bezierCurveTo(179.2, 10.0, 184.8, 9.8, 189.8, 12.8);
    ctx.bezierCurveTo(192.4, 14.4, 193.9, 17.3, 193.8, 20.4);
    ctx.bezierCurveTo(193.3, 25.2, 189.9, 29.2, 185.2, 30.4);
    ctx.bezierCurveTo(183.2, 30.8, 181.1, 30.7, 179.2, 30.1);
    ctx.lineTo(176.4, 36.1);
    ctx.bezierCurveTo(176.3, 36.2, 176.2, 36.4, 176.0, 36.4);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(177.2, 12.5);
    ctx.bezierCurveTo(175.9, 13.0, 174.6, 13.5, 173.4, 14.2);
    ctx.bezierCurveTo(173.4, 14.2, 167.7, 18.2, 169.4, 23.3);
    ctx.bezierCurveTo(170.5, 26.6, 172.2, 27.3, 173.5, 27.7);
    ctx.bezierCurveTo(173.7, 27.8, 173.9, 27.9, 174.0, 27.9);
    ctx.bezierCurveTo(174.5, 28.1, 174.8, 28.6, 174.9, 29.1);
    ctx.lineTo(175.9, 35.1);
    ctx.lineTo(178.3, 29.7);
    ctx.bezierCurveTo(178.5, 29.3, 178.9, 29.2, 179.2, 29.3);
    ctx.bezierCurveTo(184.5, 31.2, 190.4, 28.4, 192.2, 23.1);
    ctx.bezierCurveTo(192.5, 22.2, 192.7, 21.3, 192.8, 20.4);
    ctx.bezierCurveTo(192.9, 17.7, 191.6, 15.2, 189.3, 13.8);
    ctx.bezierCurveTo(185.7, 11.5, 181.2, 11.0, 177.2, 12.5);
    ctx.lineTo(177.2, 12.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(174.1, 22.1);
    ctx.bezierCurveTo(174.6, 22.0, 175.1, 22.2, 175.2, 22.7);
    ctx.bezierCurveTo(175.4, 23.2, 175.2, 23.7, 174.7, 23.9);
    ctx.bezierCurveTo(174.3, 24.0, 173.8, 23.7, 173.6, 23.3);
    ctx.bezierCurveTo(173.4, 22.8, 173.7, 22.2, 174.1, 22.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(180.8, 21.4);
    ctx.bezierCurveTo(181.2, 21.3, 181.7, 21.5, 181.9, 22.0);
    ctx.bezierCurveTo(182.1, 22.5, 181.8, 23.0, 181.4, 23.2);
    ctx.bezierCurveTo(180.9, 23.3, 180.4, 23.0, 180.2, 22.6);
    ctx.bezierCurveTo(180.1, 22.1, 180.3, 21.6, 180.8, 21.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(186.9, 19.8);
    ctx.bezierCurveTo(187.3, 19.6, 187.8, 19.9, 188.0, 20.4);
    ctx.bezierCurveTo(188.2, 20.9, 187.9, 21.4, 187.5, 21.5);
    ctx.bezierCurveTo(187.0, 21.7, 186.5, 21.4, 186.3, 20.9);
    ctx.bezierCurveTo(186.2, 20.4, 186.4, 19.9, 186.9, 19.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(246.5, 70.8);
    ctx.bezierCurveTo(246.4, 70.8, 246.3, 70.8, 246.2, 70.8);
    ctx.bezierCurveTo(246.0, 70.7, 245.8, 70.5, 245.8, 70.3);
    ctx.lineTo(245.0, 65.2);
    ctx.bezierCurveTo(245.0, 65.1, 244.9, 65.0, 244.8, 64.9);
    ctx.bezierCurveTo(244.7, 64.9, 244.6, 64.8, 244.4, 64.8);
    ctx.bezierCurveTo(242.6, 64.2, 241.2, 62.7, 240.8, 60.9);
    ctx.bezierCurveTo(239.4, 56.7, 243.5, 53.3, 244.1, 53.0);
    ctx.bezierCurveTo(248.9, 50.4, 253.3, 50.3, 257.1, 52.6);
    ctx.bezierCurveTo(259.1, 53.9, 260.3, 56.1, 260.1, 58.5);
    ctx.bezierCurveTo(259.8, 62.2, 257.1, 65.3, 253.5, 66.2);
    ctx.bezierCurveTo(252.0, 66.5, 250.4, 66.4, 248.9, 65.9);
    ctx.lineTo(246.8, 70.5);
    ctx.bezierCurveTo(246.7, 70.6, 246.6, 70.7, 246.5, 70.8);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(247.4, 52.3);
    ctx.bezierCurveTo(246.4, 52.7, 245.4, 53.1, 244.5, 53.6);
    ctx.bezierCurveTo(244.5, 53.6, 240.1, 56.7, 241.4, 60.7);
    ctx.bezierCurveTo(241.8, 62.3, 243.0, 63.6, 244.6, 64.0);
    ctx.lineTo(245.0, 64.2);
    ctx.bezierCurveTo(245.3, 64.4, 245.6, 64.7, 245.6, 65.1);
    ctx.lineTo(246.4, 69.7);
    ctx.lineTo(248.3, 65.5);
    ctx.bezierCurveTo(248.4, 65.2, 248.7, 65.1, 249.0, 65.2);
    ctx.bezierCurveTo(249.0, 65.2, 249.0, 65.2, 249.0, 65.2);
    ctx.bezierCurveTo(250.4, 65.7, 251.9, 65.8, 253.3, 65.5);
    ctx.bezierCurveTo(256.7, 64.6, 259.1, 61.8, 259.5, 58.4);
    ctx.bezierCurveTo(259.6, 56.3, 258.6, 54.3, 256.8, 53.2);
    ctx.bezierCurveTo(254.0, 51.5, 250.5, 51.1, 247.4, 52.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(245.1, 59.3);
    ctx.bezierCurveTo(245.4, 59.1, 245.8, 59.4, 245.9, 59.7);
    ctx.bezierCurveTo(246.0, 60.1, 245.9, 60.5, 245.5, 60.6);
    ctx.bezierCurveTo(245.2, 60.7, 244.8, 60.5, 244.6, 60.2);
    ctx.bezierCurveTo(244.5, 59.8, 244.7, 59.4, 245.1, 59.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(250.2, 58.7);
    ctx.bezierCurveTo(250.5, 58.6, 250.9, 58.8, 251.0, 59.2);
    ctx.bezierCurveTo(251.2, 59.6, 251.0, 60.0, 250.6, 60.1);
    ctx.bezierCurveTo(250.3, 60.2, 249.9, 60.0, 249.8, 59.6);
    ctx.bezierCurveTo(249.6, 59.2, 249.8, 58.8, 250.2, 58.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(254.9, 57.9);
    ctx.bezierCurveTo(255.2, 57.8, 255.6, 58.0, 255.7, 58.4);
    ctx.bezierCurveTo(255.9, 58.8, 255.7, 59.2, 255.3, 59.3);
    ctx.bezierCurveTo(255.0, 59.4, 254.6, 59.2, 254.5, 58.8);
    ctx.bezierCurveTo(254.3, 58.4, 254.5, 58.0, 254.9, 57.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(241.9, 23.7);
    ctx.bezierCurveTo(241.8, 23.7, 241.7, 23.7, 241.6, 23.7);
    ctx.bezierCurveTo(241.4, 23.7, 241.2, 23.5, 241.2, 23.3);
    ctx.lineTo(240.4, 18.2);
    ctx.bezierCurveTo(240.4, 18.0, 240.3, 17.9, 240.2, 17.9);
    ctx.bezierCurveTo(240.1, 17.9, 240.0, 17.8, 239.8, 17.7);
    ctx.bezierCurveTo(238.0, 17.1, 236.7, 15.7, 236.2, 13.9);
    ctx.bezierCurveTo(234.8, 9.7, 238.9, 6.3, 239.6, 5.9);
    ctx.bezierCurveTo(244.3, 3.4, 248.7, 3.2, 252.5, 5.6);
    ctx.bezierCurveTo(254.5, 6.8, 255.7, 9.1, 255.6, 11.4);
    ctx.bezierCurveTo(255.2, 15.1, 252.5, 18.2, 248.9, 19.1);
    ctx.bezierCurveTo(247.4, 19.5, 245.8, 19.4, 244.3, 18.9);
    ctx.lineTo(242.2, 23.5);
    ctx.bezierCurveTo(242.1, 23.6, 242.0, 23.7, 241.9, 23.7);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(242.8, 5.3);
    ctx.bezierCurveTo(241.8, 5.6, 240.8, 6.0, 239.9, 6.5);
    ctx.bezierCurveTo(239.9, 6.5, 235.5, 9.6, 236.8, 13.6);
    ctx.bezierCurveTo(237.2, 15.2, 238.4, 16.5, 240.0, 17.0);
    ctx.lineTo(240.4, 17.2);
    ctx.bezierCurveTo(240.8, 17.3, 241.0, 17.6, 241.0, 18.0);
    ctx.lineTo(241.8, 22.6);
    ctx.lineTo(243.7, 18.5);
    ctx.bezierCurveTo(243.8, 18.2, 244.1, 18.1, 244.4, 18.2);
    ctx.bezierCurveTo(244.4, 18.2, 244.4, 18.2, 244.4, 18.2);
    ctx.bezierCurveTo(245.8, 18.7, 247.3, 18.7, 248.7, 18.4);
    ctx.bezierCurveTo(252.1, 17.6, 254.6, 14.8, 254.9, 11.3);
    ctx.bezierCurveTo(255.0, 9.2, 254.0, 7.3, 252.2, 6.2);
    ctx.bezierCurveTo(249.4, 4.4, 245.9, 4.1, 242.8, 5.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(240.5, 12.2);
    ctx.bezierCurveTo(240.8, 12.1, 241.2, 12.3, 241.3, 12.7);
    ctx.bezierCurveTo(241.5, 13.1, 241.3, 13.5, 240.9, 13.6);
    ctx.bezierCurveTo(240.6, 13.7, 240.2, 13.5, 240.1, 13.1);
    ctx.bezierCurveTo(239.9, 12.7, 240.1, 12.3, 240.5, 12.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(245.6, 11.7);
    ctx.bezierCurveTo(245.9, 11.5, 246.3, 11.8, 246.5, 12.1);
    ctx.bezierCurveTo(246.6, 12.5, 246.4, 12.9, 246.0, 13.0);
    ctx.bezierCurveTo(245.7, 13.1, 245.3, 12.9, 245.2, 12.6);
    ctx.bezierCurveTo(245.1, 12.2, 245.2, 11.8, 245.6, 11.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(250.3, 10.9);
    ctx.bezierCurveTo(250.6, 10.8, 251.0, 11.0, 251.1, 11.3);
    ctx.bezierCurveTo(251.3, 11.7, 251.1, 12.1, 250.7, 12.2);
    ctx.bezierCurveTo(250.4, 12.4, 250.0, 12.1, 249.9, 11.8);
    ctx.bezierCurveTo(249.8, 11.4, 249.9, 11.0, 250.3, 10.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(307.0, 404.4);
    ctx.bezierCurveTo(303.2, 402.0, 298.9, 402.2, 294.1, 404.7);
    ctx.bezierCurveTo(293.5, 405.1, 289.4, 408.4, 290.8, 412.7);
    ctx.bezierCurveTo(290.9, 413.2, 291.1, 413.8, 291.4, 414.2);
    ctx.lineTo(292.3, 414.2);
    ctx.bezierCurveTo(291.8, 413.7, 291.5, 413.1, 291.4, 412.4);
    ctx.bezierCurveTo(290.1, 408.4, 294.4, 405.3, 294.4, 405.3);
    ctx.bezierCurveTo(295.4, 404.8, 296.3, 404.4, 297.4, 404.1);
    ctx.bezierCurveTo(300.5, 402.9, 303.9, 403.2, 306.7, 405.0);
    ctx.bezierCurveTo(308.5, 406.0, 309.5, 408.0, 309.5, 410.1);
    ctx.bezierCurveTo(309.3, 411.6, 308.7, 413.1, 307.8, 414.2);
    ctx.lineTo(308.7, 414.2);
    ctx.bezierCurveTo(309.5, 413.1, 310.0, 411.7, 310.1, 410.2);
    ctx.bezierCurveTo(310.2, 407.8, 309.0, 405.6, 307.0, 404.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(295.0, 411.0);
    ctx.bezierCurveTo(295.4, 410.9, 295.7, 411.1, 295.9, 411.5);
    ctx.bezierCurveTo(296.0, 411.9, 295.8, 412.3, 295.5, 412.4);
    ctx.bezierCurveTo(295.1, 412.5, 294.7, 412.3, 294.6, 411.9);
    ctx.bezierCurveTo(294.5, 411.5, 294.7, 411.1, 295.0, 411.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(300.1, 410.5);
    ctx.bezierCurveTo(300.5, 410.3, 300.9, 410.5, 301.0, 410.9);
    ctx.bezierCurveTo(301.1, 411.3, 300.9, 411.7, 300.6, 411.8);
    ctx.bezierCurveTo(300.2, 411.9, 299.9, 411.7, 299.7, 411.3);
    ctx.bezierCurveTo(299.6, 411.0, 299.8, 410.6, 300.1, 410.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(304.8, 409.7);
    ctx.bezierCurveTo(305.2, 409.5, 305.6, 409.8, 305.7, 410.1);
    ctx.bezierCurveTo(305.8, 410.5, 305.6, 410.9, 305.3, 411.0);
    ctx.bezierCurveTo(304.9, 411.1, 304.5, 410.9, 304.4, 410.6);
    ctx.bezierCurveTo(304.3, 410.2, 304.5, 409.8, 304.8, 409.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(145.8, 41.7);
    ctx.bezierCurveTo(145.7, 41.7, 145.6, 41.7, 145.5, 41.7);
    ctx.bezierCurveTo(145.3, 41.7, 145.1, 41.5, 145.1, 41.3);
    ctx.lineTo(144.3, 36.2);
    ctx.bezierCurveTo(144.3, 36.0, 144.2, 35.9, 144.1, 35.9);
    ctx.bezierCurveTo(144.0, 35.9, 143.8, 35.8, 143.7, 35.7);
    ctx.bezierCurveTo(141.9, 35.2, 140.5, 33.7, 140.1, 31.9);
    ctx.bezierCurveTo(138.7, 27.7, 142.8, 24.3, 143.4, 23.9);
    ctx.bezierCurveTo(148.2, 21.4, 152.5, 21.2, 156.4, 23.6);
    ctx.bezierCurveTo(158.4, 24.8, 159.5, 27.1, 159.4, 29.4);
    ctx.bezierCurveTo(159.1, 33.1, 156.4, 36.2, 152.8, 37.1);
    ctx.bezierCurveTo(151.2, 37.5, 149.6, 37.4, 148.2, 36.9);
    ctx.lineTo(146.0, 41.5);
    ctx.bezierCurveTo(146.0, 41.6, 145.9, 41.7, 145.8, 41.7);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(146.7, 23.3);
    ctx.bezierCurveTo(145.7, 23.6, 144.7, 24.0, 143.7, 24.5);
    ctx.bezierCurveTo(143.7, 24.5, 139.4, 27.6, 140.7, 31.6);
    ctx.bezierCurveTo(141.1, 33.2, 142.3, 34.5, 143.9, 35.0);
    ctx.lineTo(144.3, 35.2);
    ctx.bezierCurveTo(144.6, 35.3, 144.9, 35.6, 144.9, 36.0);
    ctx.lineTo(145.7, 40.6);
    ctx.lineTo(147.6, 36.5);
    ctx.bezierCurveTo(147.7, 36.2, 148.0, 36.1, 148.3, 36.2);
    ctx.bezierCurveTo(148.3, 36.2, 148.3, 36.2, 148.3, 36.2);
    ctx.bezierCurveTo(149.7, 36.7, 151.2, 36.8, 152.6, 36.4);
    ctx.bezierCurveTo(156.0, 35.6, 158.4, 32.8, 158.8, 29.3);
    ctx.bezierCurveTo(158.9, 27.2, 157.8, 25.3, 156.0, 24.2);
    ctx.bezierCurveTo(153.2, 22.4, 149.8, 22.1, 146.7, 23.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(144.3, 30.2);
    ctx.bezierCurveTo(144.7, 30.1, 145.1, 30.3, 145.2, 30.7);
    ctx.bezierCurveTo(145.3, 31.1, 145.1, 31.5, 144.8, 31.6);
    ctx.bezierCurveTo(144.4, 31.7, 144.0, 31.5, 143.9, 31.1);
    ctx.bezierCurveTo(143.8, 30.7, 144.0, 30.3, 144.3, 30.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(149.5, 29.7);
    ctx.bezierCurveTo(149.8, 29.5, 150.2, 29.8, 150.3, 30.1);
    ctx.bezierCurveTo(150.4, 30.5, 150.3, 30.9, 149.9, 31.0);
    ctx.bezierCurveTo(149.6, 31.1, 149.2, 30.9, 149.0, 30.6);
    ctx.bezierCurveTo(148.9, 30.2, 149.1, 29.8, 149.5, 29.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(154.2, 28.9);
    ctx.bezierCurveTo(154.5, 28.8, 154.9, 29.0, 155.0, 29.3);
    ctx.bezierCurveTo(155.1, 29.7, 155.0, 30.1, 154.6, 30.2);
    ctx.bezierCurveTo(154.3, 30.4, 153.9, 30.1, 153.7, 29.8);
    ctx.bezierCurveTo(153.6, 29.4, 153.8, 29.0, 154.2, 28.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(42.6, 165.1);
    ctx.bezierCurveTo(42.5, 165.1, 42.4, 165.1, 42.3, 165.1);
    ctx.bezierCurveTo(42.1, 165.1, 41.9, 164.9, 41.9, 164.7);
    ctx.lineTo(41.1, 159.5);
    ctx.bezierCurveTo(41.1, 159.4, 41.0, 159.3, 40.9, 159.2);
    ctx.lineTo(40.5, 159.1);
    ctx.bezierCurveTo(38.7, 158.5, 37.3, 157.0, 36.9, 155.2);
    ctx.bezierCurveTo(35.5, 151.0, 39.6, 147.7, 40.2, 147.3);
    ctx.bezierCurveTo(45.0, 144.7, 49.3, 144.6, 53.2, 146.9);
    ctx.bezierCurveTo(55.2, 148.2, 56.3, 150.4, 56.2, 152.8);
    ctx.bezierCurveTo(55.9, 156.5, 53.2, 159.6, 49.6, 160.5);
    ctx.bezierCurveTo(48.0, 160.8, 46.5, 160.7, 45.0, 160.2);
    ctx.lineTo(42.9, 164.8);
    ctx.bezierCurveTo(42.8, 165.0, 42.7, 165.1, 42.6, 165.1);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(43.5, 146.7);
    ctx.bezierCurveTo(42.5, 147.0, 41.5, 147.5, 40.5, 148.0);
    ctx.bezierCurveTo(40.5, 148.0, 36.2, 151.1, 37.5, 155.0);
    ctx.bezierCurveTo(37.9, 156.6, 39.1, 157.9, 40.7, 158.4);
    ctx.lineTo(41.1, 158.6);
    ctx.bezierCurveTo(41.5, 158.7, 41.7, 159.1, 41.8, 159.4);
    ctx.lineTo(42.5, 164.0);
    ctx.lineTo(44.4, 159.9);
    ctx.bezierCurveTo(44.5, 159.6, 44.8, 159.5, 45.1, 159.6);
    ctx.bezierCurveTo(46.5, 160.1, 48.0, 160.2, 49.4, 159.8);
    ctx.bezierCurveTo(52.8, 159.0, 55.3, 156.2, 55.6, 152.7);
    ctx.bezierCurveTo(55.7, 150.7, 54.7, 148.7, 52.9, 147.6);
    ctx.bezierCurveTo(50.1, 145.8, 46.6, 145.5, 43.5, 146.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(41.1, 153.6);
    ctx.bezierCurveTo(41.5, 153.5, 41.9, 153.7, 42.0, 154.1);
    ctx.bezierCurveTo(42.1, 154.5, 41.9, 154.9, 41.6, 155.0);
    ctx.bezierCurveTo(41.2, 155.1, 40.9, 154.9, 40.7, 154.5);
    ctx.bezierCurveTo(40.6, 154.1, 40.8, 153.7, 41.1, 153.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(46.3, 153.1);
    ctx.bezierCurveTo(46.6, 153.0, 47.0, 153.2, 47.1, 153.5);
    ctx.bezierCurveTo(47.3, 153.9, 47.1, 154.3, 46.7, 154.4);
    ctx.bezierCurveTo(46.4, 154.6, 46.0, 154.3, 45.9, 154.0);
    ctx.bezierCurveTo(45.7, 153.6, 45.9, 153.2, 46.3, 153.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(51.0, 152.3);
    ctx.bezierCurveTo(51.3, 152.2, 51.7, 152.4, 51.8, 152.7);
    ctx.bezierCurveTo(51.9, 153.1, 51.8, 153.5, 51.4, 153.6);
    ctx.bezierCurveTo(51.1, 153.8, 50.7, 153.5, 50.6, 153.2);
    ctx.bezierCurveTo(50.4, 152.8, 50.6, 152.4, 51.0, 152.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(21.8, 118.7);
    ctx.bezierCurveTo(21.7, 118.7, 21.6, 118.7, 21.5, 118.7);
    ctx.bezierCurveTo(21.3, 118.7, 21.1, 118.5, 21.1, 118.2);
    ctx.lineTo(20.3, 113.1);
    ctx.bezierCurveTo(20.3, 113.0, 20.2, 112.9, 20.1, 112.8);
    ctx.lineTo(19.7, 112.6);
    ctx.bezierCurveTo(17.9, 112.1, 16.5, 110.6, 16.1, 108.8);
    ctx.bezierCurveTo(14.7, 104.6, 18.8, 101.2, 19.4, 100.9);
    ctx.bezierCurveTo(24.2, 98.3, 28.5, 98.2, 32.4, 100.5);
    ctx.bezierCurveTo(34.4, 101.7, 35.5, 104.0, 35.4, 106.3);
    ctx.bezierCurveTo(35.1, 111.0, 31.0, 114.6, 26.3, 114.3);
    ctx.bezierCurveTo(25.6, 114.2, 24.9, 114.1, 24.2, 113.8);
    ctx.lineTo(22.0, 118.4);
    ctx.bezierCurveTo(22.0, 118.5, 21.9, 118.6, 21.8, 118.7);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(22.7, 100.2);
    ctx.bezierCurveTo(21.7, 100.5, 20.7, 101.0, 19.8, 101.5);
    ctx.bezierCurveTo(19.8, 101.5, 15.4, 104.6, 16.7, 108.5);
    ctx.bezierCurveTo(17.1, 110.2, 18.3, 111.5, 19.9, 111.9);
    ctx.bezierCurveTo(20.0, 112.0, 20.2, 112.1, 20.3, 112.1);
    ctx.bezierCurveTo(20.6, 112.3, 20.9, 112.6, 20.9, 112.9);
    ctx.lineTo(21.7, 117.6);
    ctx.lineTo(23.6, 113.4);
    ctx.bezierCurveTo(23.7, 113.1, 24.0, 113.0, 24.3, 113.1);
    ctx.bezierCurveTo(25.6, 113.6, 27.1, 113.7, 28.6, 113.4);
    ctx.bezierCurveTo(31.9, 112.5, 34.4, 109.7, 34.7, 106.3);
    ctx.bezierCurveTo(34.8, 104.2, 33.8, 102.3, 32.1, 101.2);
    ctx.bezierCurveTo(29.3, 99.4, 25.8, 99.1, 22.7, 100.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(20.3, 107.2);
    ctx.bezierCurveTo(20.7, 107.1, 21.1, 107.3, 21.2, 107.7);
    ctx.bezierCurveTo(21.3, 108.1, 21.2, 108.5, 20.8, 108.6);
    ctx.bezierCurveTo(20.4, 108.7, 20.1, 108.5, 19.9, 108.1);
    ctx.bezierCurveTo(19.8, 107.7, 20.0, 107.3, 20.3, 107.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(25.5, 106.6);
    ctx.bezierCurveTo(25.8, 106.5, 26.2, 106.7, 26.3, 107.1);
    ctx.bezierCurveTo(26.5, 107.5, 26.3, 107.9, 25.9, 108.0);
    ctx.bezierCurveTo(25.6, 108.1, 25.2, 107.9, 25.1, 107.5);
    ctx.bezierCurveTo(24.9, 107.1, 25.1, 106.7, 25.5, 106.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(30.2, 105.8);
    ctx.bezierCurveTo(30.5, 105.7, 30.9, 105.9, 31.0, 106.3);
    ctx.bezierCurveTo(31.2, 106.7, 31.0, 107.1, 30.6, 107.2);
    ctx.bezierCurveTo(30.3, 107.3, 29.9, 107.1, 29.8, 106.7);
    ctx.bezierCurveTo(29.6, 106.4, 29.8, 106.0, 30.2, 105.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(10.5, 259.3);
    ctx.bezierCurveTo(10.4, 259.3, 10.3, 259.3, 10.2, 259.3);
    ctx.bezierCurveTo(10.0, 259.2, 9.8, 259.1, 9.8, 258.8);
    ctx.lineTo(9.0, 253.7);
    ctx.bezierCurveTo(9.0, 253.6, 8.9, 253.5, 8.8, 253.4);
    ctx.lineTo(8.4, 253.2);
    ctx.bezierCurveTo(6.6, 252.6, 5.2, 251.2, 4.8, 249.4);
    ctx.bezierCurveTo(3.4, 245.1, 7.5, 241.8, 8.2, 241.4);
    ctx.bezierCurveTo(12.9, 238.9, 17.3, 238.7, 21.1, 241.1);
    ctx.bezierCurveTo(23.1, 242.3, 24.3, 244.5, 24.1, 246.9);
    ctx.bezierCurveTo(23.8, 250.6, 21.1, 253.7, 17.5, 254.6);
    ctx.bezierCurveTo(16.0, 255.0, 14.4, 254.9, 12.9, 254.4);
    ctx.lineTo(10.8, 259.0);
    ctx.bezierCurveTo(10.7, 259.1, 10.6, 259.2, 10.5, 259.3);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(11.4, 240.8);
    ctx.bezierCurveTo(10.4, 241.2, 9.4, 241.6, 8.5, 242.1);
    ctx.bezierCurveTo(8.5, 242.1, 4.1, 245.2, 5.4, 249.2);
    ctx.bezierCurveTo(5.8, 250.8, 7.0, 252.1, 8.6, 252.6);
    ctx.lineTo(9.0, 252.8);
    ctx.bezierCurveTo(9.3, 252.9, 9.6, 253.2, 9.6, 253.6);
    ctx.lineTo(10.4, 258.2);
    ctx.lineTo(12.3, 254.1);
    ctx.bezierCurveTo(12.4, 253.8, 12.7, 253.7, 13.0, 253.8);
    ctx.bezierCurveTo(14.4, 254.2, 15.9, 254.3, 17.3, 254.0);
    ctx.bezierCurveTo(20.7, 253.2, 23.1, 250.4, 23.5, 246.9);
    ctx.bezierCurveTo(23.6, 244.8, 22.5, 242.9, 20.8, 241.8);
    ctx.bezierCurveTo(18.0, 240.0, 14.5, 239.7, 11.4, 240.8);
    ctx.lineTo(11.4, 240.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(9.1, 247.8);
    ctx.bezierCurveTo(9.4, 247.7, 9.8, 247.9, 9.9, 248.3);
    ctx.bezierCurveTo(10.1, 248.6, 9.9, 249.0, 9.5, 249.2);
    ctx.bezierCurveTo(9.2, 249.3, 8.8, 249.1, 8.7, 248.7);
    ctx.bezierCurveTo(8.5, 248.3, 8.7, 247.9, 9.1, 247.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(14.2, 247.2);
    ctx.bezierCurveTo(14.6, 247.1, 14.9, 247.3, 15.1, 247.7);
    ctx.bezierCurveTo(15.2, 248.1, 15.0, 248.5, 14.7, 248.6);
    ctx.bezierCurveTo(14.3, 248.7, 13.9, 248.5, 13.8, 248.1);
    ctx.bezierCurveTo(13.7, 247.7, 13.9, 247.3, 14.2, 247.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(18.9, 246.4);
    ctx.bezierCurveTo(19.2, 246.3, 19.6, 246.5, 19.7, 246.9);
    ctx.bezierCurveTo(19.9, 247.3, 19.7, 247.7, 19.3, 247.8);
    ctx.bezierCurveTo(19.0, 247.9, 18.6, 247.7, 18.5, 247.3);
    ctx.bezierCurveTo(18.4, 246.9, 18.5, 246.5, 18.9, 246.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(9.0, 386.9);
    ctx.bezierCurveTo(8.9, 386.9, 8.8, 386.9, 8.8, 386.9);
    ctx.bezierCurveTo(8.5, 386.9, 8.3, 386.7, 8.3, 386.5);
    ctx.lineTo(7.5, 381.3);
    ctx.bezierCurveTo(7.5, 381.2, 7.4, 381.1, 7.3, 381.0);
    ctx.lineTo(6.9, 380.9);
    ctx.bezierCurveTo(5.1, 380.3, 3.8, 378.8, 3.3, 377.0);
    ctx.bezierCurveTo(1.9, 372.8, 6.0, 369.5, 6.7, 369.1);
    ctx.bezierCurveTo(11.4, 366.5, 15.8, 366.4, 19.6, 368.7);
    ctx.bezierCurveTo(21.6, 370.0, 22.8, 372.2, 22.7, 374.6);
    ctx.bezierCurveTo(22.3, 378.3, 19.6, 381.4, 16.0, 382.3);
    ctx.bezierCurveTo(14.5, 382.6, 12.9, 382.5, 11.4, 382.0);
    ctx.lineTo(9.2, 386.6);
    ctx.bezierCurveTo(9.2, 386.8, 9.1, 386.9, 9.0, 386.9);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(9.9, 368.5);
    ctx.bezierCurveTo(8.9, 368.8, 7.9, 369.2, 7.0, 369.7);
    ctx.bezierCurveTo(7.0, 369.7, 2.6, 372.8, 4.0, 376.8);
    ctx.bezierCurveTo(4.3, 378.4, 5.5, 379.7, 7.1, 380.2);
    ctx.lineTo(7.5, 380.4);
    ctx.bezierCurveTo(7.8, 380.5, 8.1, 380.9, 8.1, 381.2);
    ctx.lineTo(8.9, 385.8);
    ctx.lineTo(10.8, 381.7);
    ctx.bezierCurveTo(10.9, 381.4, 11.2, 381.3, 11.5, 381.4);
    ctx.bezierCurveTo(12.8, 381.9, 14.3, 382.0, 15.8, 381.6);
    ctx.bezierCurveTo(19.1, 380.8, 21.6, 378.0, 21.9, 374.5);
    ctx.bezierCurveTo(22.0, 372.5, 21.0, 370.5, 19.3, 369.4);
    ctx.bezierCurveTo(16.5, 367.6, 13.0, 367.3, 9.9, 368.5);
    ctx.lineTo(9.9, 368.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(7.6, 375.4);
    ctx.bezierCurveTo(7.9, 375.3, 8.3, 375.5, 8.4, 375.9);
    ctx.bezierCurveTo(8.5, 376.3, 8.4, 376.7, 8.0, 376.8);
    ctx.bezierCurveTo(7.7, 376.9, 7.3, 376.7, 7.1, 376.3);
    ctx.bezierCurveTo(7.0, 375.9, 7.2, 375.5, 7.6, 375.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(12.7, 374.8);
    ctx.bezierCurveTo(13.0, 374.7, 13.4, 374.9, 13.5, 375.3);
    ctx.bezierCurveTo(13.7, 375.7, 13.5, 376.1, 13.1, 376.2);
    ctx.bezierCurveTo(12.8, 376.3, 12.4, 376.1, 12.3, 375.7);
    ctx.bezierCurveTo(12.1, 375.4, 12.3, 375.0, 12.7, 374.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(17.4, 374.1);
    ctx.bezierCurveTo(17.7, 374.0, 18.1, 374.2, 18.2, 374.5);
    ctx.bezierCurveTo(18.4, 374.9, 18.2, 375.3, 17.8, 375.4);
    ctx.bezierCurveTo(17.5, 375.6, 17.1, 375.3, 17.0, 375.0);
    ctx.bezierCurveTo(16.8, 374.6, 17.0, 374.2, 17.4, 374.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(65.3, 400.2);
    ctx.bezierCurveTo(65.3, 400.2, 65.2, 400.2, 65.1, 400.2);
    ctx.bezierCurveTo(64.9, 400.2, 64.7, 400.0, 64.7, 399.7);
    ctx.lineTo(63.8, 394.6);
    ctx.bezierCurveTo(63.8, 394.5, 63.8, 394.4, 63.6, 394.3);
    ctx.lineTo(63.2, 394.1);
    ctx.bezierCurveTo(61.5, 393.6, 60.1, 392.1, 59.7, 390.3);
    ctx.bezierCurveTo(58.3, 386.1, 62.3, 382.7, 63.0, 382.4);
    ctx.bezierCurveTo(67.8, 379.8, 72.1, 379.7, 75.9, 382.0);
    ctx.bezierCurveTo(78.0, 383.3, 79.1, 385.5, 79.0, 387.9);
    ctx.bezierCurveTo(78.6, 391.6, 76.0, 394.7, 72.3, 395.6);
    ctx.bezierCurveTo(70.8, 396.0, 69.2, 395.9, 67.7, 395.4);
    ctx.lineTo(65.6, 400.0);
    ctx.bezierCurveTo(65.6, 400.1, 65.5, 400.2, 65.3, 400.2);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(66.3, 381.8);
    ctx.bezierCurveTo(65.2, 382.1, 64.3, 382.5, 63.3, 383.0);
    ctx.bezierCurveTo(63.3, 383.0, 59.0, 386.1, 60.3, 390.1);
    ctx.bezierCurveTo(60.7, 391.7, 61.9, 393.0, 63.5, 393.5);
    ctx.lineTo(63.9, 393.7);
    ctx.bezierCurveTo(64.2, 393.8, 64.5, 394.1, 64.5, 394.5);
    ctx.lineTo(65.3, 399.1);
    ctx.lineTo(67.2, 395.0);
    ctx.bezierCurveTo(67.3, 394.7, 67.6, 394.6, 67.9, 394.7);
    ctx.bezierCurveTo(72.0, 396.1, 76.5, 394.0, 77.9, 389.9);
    ctx.bezierCurveTo(78.2, 389.2, 78.3, 388.5, 78.4, 387.8);
    ctx.bezierCurveTo(78.5, 385.7, 77.4, 383.8, 75.7, 382.7);
    ctx.bezierCurveTo(72.9, 380.9, 69.4, 380.6, 66.3, 381.8);
    ctx.lineTo(66.3, 381.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(63.9, 388.7);
    ctx.bezierCurveTo(64.3, 388.6, 64.7, 388.8, 64.8, 389.2);
    ctx.bezierCurveTo(64.9, 389.6, 64.7, 390.0, 64.4, 390.1);
    ctx.bezierCurveTo(64.0, 390.2, 63.6, 390.0, 63.5, 389.6);
    ctx.bezierCurveTo(63.4, 389.3, 63.6, 388.9, 63.9, 388.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(69.0, 388.2);
    ctx.bezierCurveTo(69.4, 388.1, 69.8, 388.3, 69.9, 388.7);
    ctx.bezierCurveTo(70.0, 389.0, 69.8, 389.4, 69.5, 389.6);
    ctx.bezierCurveTo(69.1, 389.7, 68.8, 389.5, 68.6, 389.1);
    ctx.bezierCurveTo(68.5, 388.7, 68.7, 388.3, 69.0, 388.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(73.7, 387.4);
    ctx.bezierCurveTo(74.1, 387.3, 74.5, 387.5, 74.6, 387.9);
    ctx.bezierCurveTo(74.7, 388.2, 74.5, 388.6, 74.2, 388.8);
    ctx.bezierCurveTo(73.8, 388.9, 73.5, 388.7, 73.3, 388.3);
    ctx.bezierCurveTo(73.2, 387.9, 73.4, 387.5, 73.7, 387.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(122.0, 411.7);
    ctx.bezierCurveTo(121.9, 411.7, 121.8, 411.7, 121.8, 411.7);
    ctx.bezierCurveTo(121.5, 411.7, 121.4, 411.5, 121.3, 411.2);
    ctx.lineTo(120.5, 406.1);
    ctx.bezierCurveTo(120.5, 406.0, 120.4, 405.9, 120.3, 405.8);
    ctx.lineTo(119.9, 405.6);
    ctx.bezierCurveTo(118.1, 405.1, 116.8, 403.6, 116.3, 401.8);
    ctx.bezierCurveTo(114.9, 397.6, 119.0, 394.2, 119.6, 393.9);
    ctx.bezierCurveTo(124.4, 391.3, 128.8, 391.2, 132.6, 393.5);
    ctx.bezierCurveTo(134.6, 394.7, 135.8, 397.0, 135.7, 399.3);
    ctx.bezierCurveTo(135.3, 404.0, 131.3, 407.6, 126.6, 407.3);
    ctx.bezierCurveTo(125.8, 407.2, 125.1, 407.1, 124.4, 406.8);
    ctx.lineTo(122.3, 411.4);
    ctx.bezierCurveTo(122.2, 411.5, 122.1, 411.7, 122.0, 411.7);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(122.9, 393.3);
    ctx.bezierCurveTo(121.9, 393.6, 120.9, 394.0, 119.9, 394.5);
    ctx.bezierCurveTo(119.9, 394.5, 115.6, 397.6, 116.9, 401.6);
    ctx.bezierCurveTo(117.3, 403.2, 118.5, 404.5, 120.1, 405.0);
    ctx.lineTo(120.5, 405.2);
    ctx.bezierCurveTo(120.8, 405.3, 121.1, 405.6, 121.1, 406.0);
    ctx.lineTo(121.9, 410.6);
    ctx.lineTo(123.8, 406.4);
    ctx.bezierCurveTo(123.9, 406.2, 124.2, 406.1, 124.5, 406.1);
    ctx.bezierCurveTo(125.9, 406.6, 127.4, 406.7, 128.8, 406.4);
    ctx.bezierCurveTo(132.2, 405.6, 134.6, 402.8, 135.0, 399.3);
    ctx.bezierCurveTo(135.1, 397.2, 134.0, 395.3, 132.3, 394.2);
    ctx.bezierCurveTo(129.5, 392.4, 126.0, 392.1, 122.9, 393.3);
    ctx.lineTo(122.9, 393.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(120.6, 400.2);
    ctx.bezierCurveTo(120.9, 400.1, 121.3, 400.3, 121.5, 400.7);
    ctx.bezierCurveTo(121.6, 401.0, 121.4, 401.4, 121.0, 401.6);
    ctx.bezierCurveTo(120.7, 401.7, 120.3, 401.5, 120.2, 401.1);
    ctx.bezierCurveTo(120.1, 400.7, 120.2, 400.3, 120.6, 400.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(125.7, 399.6);
    ctx.bezierCurveTo(126.1, 399.5, 126.5, 399.7, 126.6, 400.1);
    ctx.bezierCurveTo(126.7, 400.5, 126.5, 400.9, 126.2, 401.0);
    ctx.bezierCurveTo(125.8, 401.1, 125.4, 400.9, 125.3, 400.5);
    ctx.bezierCurveTo(125.2, 400.2, 125.4, 399.8, 125.7, 399.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(130.4, 398.9);
    ctx.bezierCurveTo(130.8, 398.7, 131.2, 399.0, 131.3, 399.3);
    ctx.bezierCurveTo(131.4, 399.7, 131.2, 400.1, 130.9, 400.2);
    ctx.bezierCurveTo(130.5, 400.3, 130.1, 400.1, 130.0, 399.8);
    ctx.bezierCurveTo(129.9, 399.4, 130.1, 399.0, 130.4, 398.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(394.7, 313.4);
    ctx.bezierCurveTo(394.6, 313.5, 394.6, 313.5, 394.5, 313.4);
    ctx.bezierCurveTo(394.3, 313.4, 394.1, 313.2, 394.1, 313.0);
    ctx.lineTo(393.2, 307.8);
    ctx.bezierCurveTo(393.2, 307.7, 393.1, 307.6, 393.0, 307.6);
    ctx.lineTo(392.6, 307.4);
    ctx.bezierCurveTo(390.8, 306.8, 389.5, 305.4, 389.1, 303.5);
    ctx.bezierCurveTo(387.7, 299.3, 391.7, 296.0, 392.4, 295.6);
    ctx.bezierCurveTo(397.2, 293.0, 401.5, 292.9, 405.3, 295.2);
    ctx.bezierCurveTo(407.3, 296.5, 408.5, 298.7, 408.4, 301.1);
    ctx.bezierCurveTo(408.1, 305.8, 404.0, 309.3, 399.3, 309.0);
    ctx.bezierCurveTo(398.5, 308.9, 397.8, 308.8, 397.1, 308.6);
    ctx.lineTo(395.0, 313.2);
    ctx.bezierCurveTo(394.9, 313.3, 394.8, 313.4, 394.7, 313.4);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(395.7, 295.0);
    ctx.bezierCurveTo(394.6, 295.3, 393.6, 295.7, 392.7, 296.3);
    ctx.bezierCurveTo(392.7, 296.3, 388.4, 299.4, 389.7, 303.3);
    ctx.bezierCurveTo(390.1, 304.9, 391.3, 306.2, 392.9, 306.7);
    ctx.bezierCurveTo(393.0, 306.8, 393.2, 306.8, 393.3, 306.9);
    ctx.bezierCurveTo(393.6, 307.0, 393.9, 307.4, 393.9, 307.7);
    ctx.lineTo(394.7, 312.3);
    ctx.lineTo(396.6, 308.2);
    ctx.bezierCurveTo(396.7, 307.9, 397.0, 307.8, 397.3, 307.9);
    ctx.bezierCurveTo(398.6, 308.4, 400.1, 308.5, 401.6, 308.1);
    ctx.bezierCurveTo(404.9, 307.3, 407.4, 304.5, 407.7, 301.0);
    ctx.bezierCurveTo(407.8, 299.0, 406.8, 297.0, 405.0, 295.9);
    ctx.bezierCurveTo(402.2, 294.2, 398.7, 293.8, 395.6, 295.0);
    ctx.lineTo(395.7, 295.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(393.3, 301.9);
    ctx.bezierCurveTo(393.7, 301.8, 394.0, 302.0, 394.2, 302.4);
    ctx.bezierCurveTo(394.3, 302.8, 394.1, 303.2, 393.8, 303.3);
    ctx.bezierCurveTo(393.4, 303.4, 393.0, 303.2, 392.9, 302.8);
    ctx.bezierCurveTo(392.8, 302.4, 393.0, 302.0, 393.3, 301.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(398.4, 301.4);
    ctx.bezierCurveTo(398.8, 301.3, 399.2, 301.5, 399.3, 301.8);
    ctx.bezierCurveTo(399.4, 302.2, 399.2, 302.6, 398.9, 302.7);
    ctx.bezierCurveTo(398.5, 302.9, 398.1, 302.6, 398.0, 302.3);
    ctx.bezierCurveTo(397.9, 301.9, 398.1, 301.5, 398.4, 301.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(403.1, 300.6);
    ctx.bezierCurveTo(403.5, 300.5, 403.9, 300.7, 404.0, 301.1);
    ctx.bezierCurveTo(404.1, 301.4, 403.9, 301.8, 403.6, 301.9);
    ctx.bezierCurveTo(403.2, 302.1, 402.8, 301.8, 402.7, 301.5);
    ctx.bezierCurveTo(402.6, 301.1, 402.8, 300.7, 403.1, 300.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Compound Path
    ctx.restore();
    ctx.beginPath();

    // layer1/Compound Path/Path
    ctx.moveTo(409.5, 347.6);
    ctx.bezierCurveTo(410.5, 347.1, 411.5, 346.7, 412.5, 346.3);
    ctx.bezierCurveTo(413.4, 346.0, 414.3, 345.8, 415.2, 345.7);
    ctx.lineTo(415.2, 345.0);
    ctx.bezierCurveTo(413.3, 345.2, 411.3, 345.8, 409.2, 347.0);
    ctx.bezierCurveTo(408.6, 347.3, 404.5, 350.7, 405.9, 354.9);
    ctx.bezierCurveTo(406.3, 356.7, 407.7, 358.2, 409.5, 358.7);
    ctx.lineTo(409.9, 358.9);
    ctx.bezierCurveTo(410.0, 359.0, 410.0, 359.1, 410.1, 359.2);
    ctx.lineTo(410.9, 364.3);
    ctx.bezierCurveTo(410.9, 364.6, 411.1, 364.7, 411.3, 364.8);
    ctx.bezierCurveTo(411.4, 364.8, 411.5, 364.8, 411.6, 364.8);
    ctx.bezierCurveTo(411.7, 364.7, 411.8, 364.7, 411.8, 364.6);
    ctx.lineTo(414.0, 359.9);
    ctx.bezierCurveTo(414.4, 360.1, 414.8, 360.2, 415.2, 360.2);
    ctx.lineTo(415.2, 359.5);
    ctx.bezierCurveTo(414.8, 359.5, 414.5, 359.4, 414.1, 359.2);
    ctx.bezierCurveTo(413.8, 359.1, 413.5, 359.3, 413.4, 359.5);
    ctx.lineTo(411.5, 363.7);
    ctx.lineTo(410.7, 359.1);
    ctx.bezierCurveTo(410.7, 358.7, 410.5, 358.4, 410.1, 358.2);
    ctx.bezierCurveTo(410.0, 358.2, 409.9, 358.1, 409.7, 358.1);
    ctx.bezierCurveTo(408.1, 357.6, 406.9, 356.3, 406.5, 354.7);
    ctx.bezierCurveTo(405.2, 350.7, 409.5, 347.6, 409.5, 347.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(410.1, 353.3);
    ctx.bezierCurveTo(410.5, 353.2, 410.9, 353.4, 411.0, 353.8);
    ctx.bezierCurveTo(411.1, 354.1, 410.9, 354.5, 410.6, 354.7);
    ctx.bezierCurveTo(410.2, 354.8, 409.9, 354.6, 409.7, 354.2);
    ctx.bezierCurveTo(409.6, 353.8, 409.8, 353.4, 410.1, 353.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(415.2, 352.8);
    ctx.lineTo(415.2, 354.0);
    ctx.bezierCurveTo(415.0, 354.0, 414.9, 353.8, 414.8, 353.6);
    ctx.bezierCurveTo(414.7, 353.3, 414.9, 352.9, 415.2, 352.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(8.2, 346.6);
    ctx.bezierCurveTo(5.7, 345.1, 2.9, 344.6, 0.0, 345.2);
    ctx.lineTo(0.0, 345.9);
    ctx.bezierCurveTo(2.7, 345.3, 5.5, 345.8, 7.8, 347.3);
    ctx.bezierCurveTo(9.6, 348.3, 10.7, 350.3, 10.6, 352.4);
    ctx.bezierCurveTo(10.2, 355.8, 7.8, 358.7, 4.4, 359.5);
    ctx.bezierCurveTo(3.0, 359.8, 1.5, 359.7, 0.1, 359.2);
    ctx.bezierCurveTo(0.0, 359.2, 0.0, 359.2, 0.0, 359.2);
    ctx.lineTo(0.0, 359.9);
    ctx.bezierCurveTo(0.7, 360.2, 1.4, 360.3, 2.1, 360.3);
    ctx.bezierCurveTo(6.8, 360.7, 10.9, 357.1, 11.2, 352.4);
    ctx.bezierCurveTo(11.3, 350.1, 10.2, 347.8, 8.2, 346.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(1.3, 352.7);
    ctx.bezierCurveTo(1.6, 352.6, 2.0, 352.8, 2.1, 353.2);
    ctx.bezierCurveTo(2.2, 353.6, 2.1, 354.0, 1.7, 354.1);
    ctx.bezierCurveTo(1.4, 354.2, 1.0, 354.0, 0.9, 353.6);
    ctx.bezierCurveTo(0.7, 353.2, 0.9, 352.8, 1.3, 352.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(6.0, 351.9);
    ctx.bezierCurveTo(6.3, 351.8, 6.7, 352.0, 6.8, 352.4);
    ctx.bezierCurveTo(6.9, 352.8, 6.8, 353.2, 6.4, 353.3);
    ctx.bezierCurveTo(6.1, 353.4, 5.7, 353.2, 5.5, 352.8);
    ctx.bezierCurveTo(5.4, 352.4, 5.6, 352.0, 6.0, 351.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(371.1, 407.4);
    ctx.bezierCurveTo(371.1, 407.4, 371.0, 407.4, 370.9, 407.4);
    ctx.bezierCurveTo(370.7, 407.3, 370.5, 407.2, 370.5, 406.9);
    ctx.lineTo(369.6, 401.8);
    ctx.bezierCurveTo(369.6, 401.7, 369.6, 401.6, 369.4, 401.5);
    ctx.bezierCurveTo(369.3, 401.5, 369.2, 401.4, 369.0, 401.3);
    ctx.bezierCurveTo(367.3, 400.8, 365.9, 399.3, 365.5, 397.5);
    ctx.bezierCurveTo(364.1, 393.3, 368.1, 389.9, 368.8, 389.6);
    ctx.bezierCurveTo(373.6, 387.0, 377.9, 386.8, 381.7, 389.2);
    ctx.bezierCurveTo(383.7, 390.4, 384.9, 392.7, 384.8, 395.0);
    ctx.bezierCurveTo(384.4, 398.8, 381.8, 401.9, 378.1, 402.8);
    ctx.bezierCurveTo(376.6, 403.1, 375.0, 403.0, 373.5, 402.5);
    ctx.lineTo(371.4, 407.1);
    ctx.bezierCurveTo(371.4, 407.2, 371.3, 407.3, 371.1, 407.4);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(372.1, 388.9);
    ctx.bezierCurveTo(371.0, 389.3, 370.1, 389.7, 369.1, 390.2);
    ctx.bezierCurveTo(369.1, 390.2, 364.8, 393.3, 366.1, 397.3);
    ctx.bezierCurveTo(366.4, 398.9, 367.7, 400.2, 369.2, 400.7);
    ctx.bezierCurveTo(369.4, 400.7, 369.5, 400.8, 369.7, 400.8);
    ctx.bezierCurveTo(370.0, 401.0, 370.2, 401.3, 370.3, 401.7);
    ctx.lineTo(371.0, 406.3);
    ctx.lineTo(373.0, 402.1);
    ctx.bezierCurveTo(373.1, 401.9, 373.4, 401.7, 373.6, 401.8);
    ctx.bezierCurveTo(375.0, 402.3, 376.5, 402.4, 378.0, 402.1);
    ctx.bezierCurveTo(381.3, 401.3, 383.8, 398.4, 384.1, 395.0);
    ctx.bezierCurveTo(384.2, 392.9, 383.2, 391.0, 381.4, 389.9);
    ctx.bezierCurveTo(378.6, 388.1, 375.2, 387.8, 372.1, 388.9);
    ctx.lineTo(372.1, 388.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(369.7, 395.9);
    ctx.bezierCurveTo(370.1, 395.8, 370.5, 396.0, 370.6, 396.4);
    ctx.bezierCurveTo(370.7, 396.7, 370.5, 397.1, 370.2, 397.3);
    ctx.bezierCurveTo(369.8, 397.4, 369.4, 397.2, 369.3, 396.8);
    ctx.bezierCurveTo(369.2, 396.4, 369.4, 396.0, 369.7, 395.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(374.8, 395.3);
    ctx.bezierCurveTo(375.2, 395.2, 375.6, 395.4, 375.7, 395.8);
    ctx.bezierCurveTo(375.8, 396.2, 375.6, 396.6, 375.3, 396.7);
    ctx.bezierCurveTo(374.9, 396.8, 374.6, 396.6, 374.4, 396.2);
    ctx.bezierCurveTo(374.3, 395.8, 374.5, 395.4, 374.8, 395.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(379.6, 394.5);
    ctx.bezierCurveTo(379.9, 394.4, 380.3, 394.6, 380.4, 395.0);
    ctx.bezierCurveTo(380.5, 395.4, 380.4, 395.8, 380.0, 395.9);
    ctx.bezierCurveTo(379.7, 396.0, 379.3, 395.8, 379.1, 395.4);
    ctx.bezierCurveTo(379.0, 395.0, 379.2, 394.6, 379.6, 394.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(275.9, 76.5);
    ctx.bezierCurveTo(275.8, 76.6, 275.7, 76.6, 275.6, 76.5);
    ctx.bezierCurveTo(275.3, 76.5, 275.1, 76.3, 275.1, 76.0);
    ctx.lineTo(274.1, 69.7);
    ctx.bezierCurveTo(274.1, 69.6, 274.0, 69.4, 273.8, 69.4);
    ctx.bezierCurveTo(273.7, 69.4, 273.5, 69.2, 273.3, 69.2);
    ctx.bezierCurveTo(272.1, 68.7, 270.1, 67.9, 269.0, 64.5);
    ctx.bezierCurveTo(267.3, 59.3, 272.2, 55.3, 273.0, 54.8);
    ctx.bezierCurveTo(278.9, 51.7, 284.2, 51.5, 288.8, 54.3);
    ctx.bezierCurveTo(291.3, 55.9, 292.7, 58.6, 292.5, 61.5);
    ctx.bezierCurveTo(292.1, 66.0, 288.9, 69.8, 284.4, 70.9);
    ctx.bezierCurveTo(282.6, 71.3, 280.6, 71.2, 278.8, 70.6);
    ctx.lineTo(276.2, 76.2);
    ctx.bezierCurveTo(276.2, 76.4, 276.1, 76.5, 275.9, 76.5);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(277.0, 54.1);
    ctx.bezierCurveTo(275.8, 54.5, 274.6, 55.0, 273.4, 55.6);
    ctx.bezierCurveTo(273.4, 55.6, 268.1, 59.4, 269.7, 64.2);
    ctx.bezierCurveTo(270.7, 67.2, 272.4, 67.9, 273.6, 68.3);
    ctx.bezierCurveTo(273.8, 68.4, 273.9, 68.5, 274.1, 68.5);
    ctx.bezierCurveTo(274.5, 68.7, 274.8, 69.1, 274.8, 69.5);
    ctx.lineTo(275.7, 75.2);
    ctx.lineTo(278.1, 70.1);
    ctx.bezierCurveTo(278.2, 69.8, 278.6, 69.6, 278.9, 69.7);
    ctx.bezierCurveTo(280.6, 70.3, 282.4, 70.4, 284.2, 70.1);
    ctx.bezierCurveTo(288.3, 69.0, 291.3, 65.6, 291.7, 61.4);
    ctx.bezierCurveTo(291.8, 58.9, 290.5, 56.5, 288.4, 55.2);
    ctx.bezierCurveTo(285.0, 53.1, 280.8, 52.6, 277.0, 54.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(274.2, 62.5);
    ctx.bezierCurveTo(274.6, 62.4, 275.1, 62.6, 275.2, 63.1);
    ctx.bezierCurveTo(275.4, 63.6, 275.2, 64.1, 274.7, 64.2);
    ctx.bezierCurveTo(274.3, 64.3, 273.8, 64.1, 273.7, 63.6);
    ctx.bezierCurveTo(273.5, 63.2, 273.7, 62.7, 274.2, 62.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(280.4, 61.8);
    ctx.bezierCurveTo(280.9, 61.7, 281.3, 62.0, 281.5, 62.4);
    ctx.bezierCurveTo(281.6, 62.9, 281.4, 63.4, 281.0, 63.5);
    ctx.bezierCurveTo(280.5, 63.6, 280.1, 63.4, 279.9, 62.9);
    ctx.bezierCurveTo(279.8, 62.5, 280.0, 62.0, 280.4, 61.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(286.1, 60.9);
    ctx.bezierCurveTo(286.6, 60.7, 287.0, 61.0, 287.2, 61.4);
    ctx.bezierCurveTo(287.3, 61.9, 287.1, 62.4, 286.7, 62.5);
    ctx.bezierCurveTo(286.3, 62.7, 285.8, 62.4, 285.6, 62.0);
    ctx.bezierCurveTo(285.5, 61.5, 285.7, 61.0, 286.1, 60.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(412.1, 12.2);
    ctx.bezierCurveTo(411.7, 12.0, 411.4, 12.2, 411.2, 12.5);
    ctx.lineTo(408.9, 17.6);
    ctx.lineTo(408.0, 12.0);
    ctx.bezierCurveTo(407.9, 11.5, 407.6, 11.2, 407.2, 11.0);
    ctx.bezierCurveTo(407.1, 10.9, 406.9, 10.9, 406.7, 10.8);
    ctx.bezierCurveTo(405.5, 10.4, 403.8, 9.7, 402.8, 6.7);
    ctx.bezierCurveTo(402.0, 4.1, 403.1, 1.8, 404.4, 0.2);
    ctx.lineTo(403.3, 0.2);
    ctx.bezierCurveTo(402.1, 1.9, 401.3, 4.3, 402.1, 6.9);
    ctx.bezierCurveTo(403.3, 10.3, 405.2, 11.1, 406.5, 11.6);
    ctx.bezierCurveTo(406.7, 11.7, 406.8, 11.8, 407.0, 11.8);
    ctx.bezierCurveTo(407.1, 11.9, 407.2, 12.0, 407.2, 12.1);
    ctx.lineTo(408.2, 18.4);
    ctx.bezierCurveTo(408.3, 18.7, 408.5, 18.9, 408.8, 19.0);
    ctx.bezierCurveTo(408.9, 19.0, 409.0, 19.0, 409.1, 19.0);
    ctx.bezierCurveTo(409.2, 18.9, 409.3, 18.8, 409.4, 18.6);
    ctx.lineTo(412.0, 13.0);
    ctx.bezierCurveTo(413.0, 13.4, 414.1, 13.6, 415.2, 13.6);
    ctx.lineTo(415.2, 12.7);
    ctx.bezierCurveTo(414.1, 12.7, 413.1, 12.5, 412.1, 12.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(407.3, 5.0);
    ctx.bezierCurveTo(407.8, 4.8, 408.2, 5.1, 408.4, 5.5);
    ctx.bezierCurveTo(408.5, 6.0, 408.3, 6.5, 407.9, 6.6);
    ctx.bezierCurveTo(407.4, 6.8, 407.0, 6.5, 406.8, 6.1);
    ctx.bezierCurveTo(406.7, 5.6, 406.9, 5.1, 407.3, 5.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(413.6, 4.3);
    ctx.bezierCurveTo(414.0, 4.1, 414.5, 4.4, 414.6, 4.9);
    ctx.bezierCurveTo(414.8, 5.3, 414.6, 5.8, 414.1, 5.9);
    ctx.bezierCurveTo(413.7, 6.1, 413.2, 5.8, 413.1, 5.4);
    ctx.bezierCurveTo(412.9, 4.9, 413.1, 4.4, 413.6, 4.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(11.0, 0.2);
    ctx.lineTo(10.0, 0.2);
    ctx.bezierCurveTo(10.6, 1.3, 10.9, 2.5, 10.8, 3.8);
    ctx.bezierCurveTo(10.4, 8.0, 7.4, 11.5, 3.3, 12.5);
    ctx.bezierCurveTo(2.2, 12.7, 1.1, 12.8, 0.0, 12.6);
    ctx.lineTo(0.0, 13.5);
    ctx.bezierCurveTo(1.2, 13.6, 2.4, 13.6, 3.6, 13.3);
    ctx.bezierCurveTo(8.0, 12.2, 11.3, 8.4, 11.7, 3.9);
    ctx.bezierCurveTo(11.8, 2.6, 11.5, 1.3, 11.0, 0.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(0.1, 5.9);
    ctx.bezierCurveTo(0.1, 6.0, 0.0, 6.0, 0.0, 6.0);
    ctx.lineTo(0.0, 4.3);
    ctx.bezierCurveTo(0.3, 4.3, 0.5, 4.5, 0.6, 4.8);
    ctx.bezierCurveTo(0.8, 5.3, 0.5, 5.8, 0.1, 5.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(5.3, 3.3);
    ctx.bezierCurveTo(5.7, 3.2, 6.2, 3.4, 6.3, 3.9);
    ctx.bezierCurveTo(6.5, 4.3, 6.3, 4.8, 5.8, 5.0);
    ctx.bezierCurveTo(5.4, 5.1, 4.9, 4.9, 4.8, 4.4);
    ctx.bezierCurveTo(4.6, 3.9, 4.9, 3.5, 5.3, 3.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(8.0, 410.8);
    ctx.bezierCurveTo(5.5, 409.3, 2.8, 408.6, 0.0, 408.8);
    ctx.lineTo(0.0, 409.7);
    ctx.bezierCurveTo(2.6, 409.5, 5.3, 410.2, 7.6, 411.6);
    ctx.bezierCurveTo(8.6, 412.3, 9.5, 413.2, 10.0, 414.2);
    ctx.lineTo(11.0, 414.2);
    ctx.bezierCurveTo(10.3, 412.8, 9.3, 411.6, 8.0, 410.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(406.2, 411.2);
    ctx.bezierCurveTo(405.8, 411.5, 404.4, 412.6, 403.3, 414.2);
    ctx.lineTo(404.3, 414.2);
    ctx.bezierCurveTo(405.4, 412.9, 406.6, 412.0, 406.6, 412.0);
    ctx.bezierCurveTo(407.7, 411.4, 408.9, 410.9, 410.2, 410.5);
    ctx.bezierCurveTo(411.8, 409.9, 413.5, 409.6, 415.2, 409.7);
    ctx.lineTo(415.2, 408.8);
    ctx.bezierCurveTo(412.4, 408.7, 409.4, 409.5, 406.2, 411.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(294.4, 36.2);
    ctx.bezierCurveTo(294.3, 36.3, 294.2, 36.3, 294.1, 36.2);
    ctx.bezierCurveTo(293.8, 36.2, 293.6, 36.0, 293.5, 35.7);
    ctx.lineTo(292.5, 29.4);
    ctx.bezierCurveTo(292.5, 29.3, 292.4, 29.1, 292.3, 29.1);
    ctx.bezierCurveTo(292.2, 29.1, 292.0, 28.9, 291.8, 28.9);
    ctx.bezierCurveTo(290.5, 28.4, 288.6, 27.6, 287.5, 24.2);
    ctx.bezierCurveTo(285.8, 19.1, 290.7, 15.0, 291.5, 14.5);
    ctx.bezierCurveTo(297.3, 11.4, 302.6, 11.2, 307.3, 14.1);
    ctx.bezierCurveTo(309.7, 15.6, 311.2, 18.3, 311.0, 21.2);
    ctx.bezierCurveTo(310.6, 25.8, 307.4, 29.6, 302.9, 30.7);
    ctx.bezierCurveTo(301.0, 31.1, 299.1, 31.0, 297.3, 30.3);
    ctx.lineTo(294.7, 36.0);
    ctx.bezierCurveTo(294.6, 36.1, 294.5, 36.2, 294.4, 36.2);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(295.5, 13.8);
    ctx.bezierCurveTo(294.3, 14.2, 293.1, 14.7, 291.9, 15.3);
    ctx.bezierCurveTo(291.9, 15.3, 286.6, 19.1, 288.2, 23.9);
    ctx.bezierCurveTo(289.2, 26.9, 290.8, 27.6, 292.1, 28.1);
    ctx.bezierCurveTo(292.3, 28.1, 292.4, 28.2, 292.6, 28.3);
    ctx.bezierCurveTo(293.0, 28.4, 293.3, 28.8, 293.3, 29.3);
    ctx.lineTo(294.2, 34.9);
    ctx.lineTo(296.6, 29.8);
    ctx.bezierCurveTo(296.7, 29.5, 297.1, 29.3, 297.4, 29.4);
    ctx.bezierCurveTo(299.1, 30.0, 300.9, 30.1, 302.7, 29.8);
    ctx.bezierCurveTo(306.8, 28.7, 309.8, 25.3, 310.2, 21.1);
    ctx.bezierCurveTo(310.3, 18.6, 309.1, 16.2, 306.9, 14.8);
    ctx.bezierCurveTo(303.5, 12.7, 299.3, 12.3, 295.5, 13.8);
    ctx.lineTo(295.5, 13.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(292.6, 22.2);
    ctx.bezierCurveTo(293.1, 22.1, 293.5, 22.3, 293.7, 22.8);
    ctx.bezierCurveTo(293.8, 23.3, 293.6, 23.7, 293.2, 23.9);
    ctx.bezierCurveTo(292.8, 24.0, 292.3, 23.8, 292.1, 23.3);
    ctx.bezierCurveTo(292.0, 22.9, 292.2, 22.4, 292.6, 22.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(298.9, 21.5);
    ctx.bezierCurveTo(299.3, 21.4, 299.8, 21.7, 299.9, 22.1);
    ctx.bezierCurveTo(300.1, 22.6, 299.9, 23.1, 299.4, 23.2);
    ctx.bezierCurveTo(299.0, 23.4, 298.5, 23.1, 298.4, 22.6);
    ctx.bezierCurveTo(298.2, 22.2, 298.5, 21.7, 298.9, 21.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(304.6, 20.6);
    ctx.bezierCurveTo(305.0, 20.4, 305.5, 20.7, 305.7, 21.1);
    ctx.bezierCurveTo(305.8, 21.6, 305.6, 22.1, 305.2, 22.2);
    ctx.bezierCurveTo(304.7, 22.4, 304.3, 22.1, 304.1, 21.7);
    ctx.bezierCurveTo(303.9, 21.2, 304.2, 20.7, 304.6, 20.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(94.0, 278.9);
    ctx.bezierCurveTo(93.8, 278.9, 93.7, 278.9, 93.5, 278.9);
    ctx.bezierCurveTo(93.1, 278.9, 92.8, 278.6, 92.7, 278.2);
    ctx.lineTo(91.0, 269.4);
    ctx.bezierCurveTo(91.0, 269.2, 90.8, 269.0, 90.6, 268.9);
    ctx.bezierCurveTo(90.4, 268.9, 90.2, 268.8, 89.9, 268.7);
    ctx.bezierCurveTo(87.9, 268.1, 84.9, 267.3, 83.0, 262.5);
    ctx.bezierCurveTo(80.3, 255.4, 87.9, 249.0, 89.1, 248.3);
    ctx.bezierCurveTo(98.1, 243.2, 106.2, 242.3, 113.4, 245.8);
    ctx.bezierCurveTo(114.1, 246.1, 119.7, 249.1, 119.3, 255.6);
    ctx.bezierCurveTo(118.8, 262.8, 112.7, 268.3, 107.0, 269.9);
    ctx.bezierCurveTo(104.2, 270.7, 101.2, 270.8, 98.3, 270.1);
    ctx.lineTo(94.4, 278.4);
    ctx.bezierCurveTo(94.3, 278.6, 94.2, 278.8, 94.0, 278.9);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(95.3, 246.7);
    ctx.bezierCurveTo(93.4, 247.5, 91.6, 248.4, 89.8, 249.4);
    ctx.bezierCurveTo(89.7, 249.4, 81.7, 255.4, 84.2, 262.1);
    ctx.bezierCurveTo(85.8, 266.3, 88.4, 267.1, 90.2, 267.5);
    ctx.bezierCurveTo(90.6, 267.6, 90.8, 267.7, 91.0, 267.7);
    ctx.bezierCurveTo(91.7, 267.9, 92.1, 268.5, 92.2, 269.1);
    ctx.lineTo(93.7, 277.0);
    ctx.lineTo(97.2, 269.5);
    ctx.bezierCurveTo(97.5, 269.0, 98.0, 268.8, 98.5, 268.9);
    ctx.bezierCurveTo(101.2, 269.6, 104.0, 269.5, 106.7, 268.8);
    ctx.bezierCurveTo(112.0, 267.2, 117.7, 262.2, 118.1, 255.6);
    ctx.bezierCurveTo(118.4, 249.9, 113.5, 247.3, 112.9, 247.1);
    ctx.bezierCurveTo(107.6, 244.4, 101.7, 244.3, 95.3, 246.7);
    ctx.lineTo(95.3, 246.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(91.0, 259.1);
    ctx.bezierCurveTo(91.7, 258.9, 92.4, 259.2, 92.7, 259.8);
    ctx.bezierCurveTo(92.9, 260.5, 92.6, 261.2, 91.9, 261.5);
    ctx.bezierCurveTo(91.3, 261.7, 90.5, 261.4, 90.3, 260.8);
    ctx.bezierCurveTo(90.0, 260.1, 90.4, 259.4, 91.0, 259.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(100.6, 257.5);
    ctx.bezierCurveTo(101.3, 257.2, 102.0, 257.5, 102.3, 258.2);
    ctx.bezierCurveTo(102.5, 258.8, 102.2, 259.5, 101.5, 259.8);
    ctx.bezierCurveTo(100.9, 260.0, 100.1, 259.7, 99.9, 259.1);
    ctx.bezierCurveTo(99.6, 258.4, 100.0, 257.7, 100.6, 257.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(109.4, 255.4);
    ctx.bezierCurveTo(110.1, 255.2, 110.8, 255.5, 111.1, 256.1);
    ctx.bezierCurveTo(111.3, 256.8, 111.0, 257.5, 110.3, 257.8);
    ctx.bezierCurveTo(109.7, 258.0, 108.9, 257.7, 108.7, 257.1);
    ctx.bezierCurveTo(108.4, 256.4, 108.8, 255.7, 109.4, 255.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(86.0, 380.6);
    ctx.bezierCurveTo(85.9, 380.6, 85.8, 380.6, 85.7, 380.6);
    ctx.bezierCurveTo(85.3, 380.6, 85.1, 380.3, 85.0, 380.0);
    ctx.lineTo(83.8, 373.4);
    ctx.bezierCurveTo(83.8, 373.3, 83.7, 373.2, 83.5, 373.1);
    ctx.bezierCurveTo(83.4, 373.1, 83.2, 373.0, 82.9, 372.9);
    ctx.bezierCurveTo(80.5, 372.5, 78.6, 370.7, 77.9, 368.3);
    ctx.bezierCurveTo(75.9, 363.0, 81.5, 358.2, 82.4, 357.7);
    ctx.bezierCurveTo(89.1, 353.9, 95.2, 353.2, 100.6, 355.9);
    ctx.bezierCurveTo(101.0, 356.1, 105.3, 358.3, 104.9, 363.1);
    ctx.bezierCurveTo(104.6, 368.5, 100.0, 372.6, 95.8, 373.8);
    ctx.bezierCurveTo(93.6, 374.4, 91.4, 374.5, 89.3, 374.0);
    ctx.lineTo(86.4, 380.2);
    ctx.bezierCurveTo(86.3, 380.4, 86.2, 380.5, 86.0, 380.6);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(87.0, 356.6);
    ctx.bezierCurveTo(85.6, 357.2, 84.2, 357.8, 82.9, 358.6);
    ctx.bezierCurveTo(82.9, 358.6, 76.8, 363.1, 78.7, 368.1);
    ctx.bezierCurveTo(79.3, 370.2, 81.1, 371.8, 83.2, 372.1);
    ctx.bezierCurveTo(83.5, 372.2, 83.7, 372.3, 83.8, 372.3);
    ctx.bezierCurveTo(84.3, 372.5, 84.6, 372.8, 84.7, 373.3);
    ctx.lineTo(85.8, 379.2);
    ctx.lineTo(88.5, 373.6);
    ctx.bezierCurveTo(88.6, 373.2, 89.1, 373.0, 89.5, 373.2);
    ctx.bezierCurveTo(91.5, 373.6, 93.6, 373.6, 95.6, 373.1);
    ctx.bezierCurveTo(99.6, 371.9, 103.7, 368.1, 104.1, 363.2);
    ctx.bezierCurveTo(104.2, 360.5, 102.7, 358.0, 100.2, 356.8);
    ctx.bezierCurveTo(96.2, 354.8, 91.8, 354.8, 87.0, 356.6);
    ctx.lineTo(87.0, 356.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(83.8, 365.8);
    ctx.bezierCurveTo(84.3, 365.7, 84.9, 365.9, 85.0, 366.4);
    ctx.bezierCurveTo(85.2, 366.8, 85.0, 367.4, 84.5, 367.6);
    ctx.bezierCurveTo(84.0, 367.8, 83.5, 367.5, 83.3, 367.0);
    ctx.bezierCurveTo(83.1, 366.6, 83.3, 366.0, 83.8, 365.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(91.0, 364.6);
    ctx.bezierCurveTo(91.5, 364.4, 92.1, 364.6, 92.2, 365.1);
    ctx.bezierCurveTo(92.4, 365.6, 92.2, 366.1, 91.7, 366.3);
    ctx.bezierCurveTo(91.2, 366.5, 90.6, 366.3, 90.5, 365.8);
    ctx.bezierCurveTo(90.3, 365.3, 90.5, 364.8, 91.0, 364.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(97.6, 363.1);
    ctx.bezierCurveTo(98.1, 362.9, 98.6, 363.1, 98.8, 363.6);
    ctx.bezierCurveTo(99.0, 364.1, 98.7, 364.6, 98.2, 364.8);
    ctx.bezierCurveTo(97.7, 365.0, 97.2, 364.8, 97.0, 364.3);
    ctx.bezierCurveTo(96.8, 363.8, 97.1, 363.3, 97.6, 363.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(93.7, 407.9);
    ctx.bezierCurveTo(93.6, 407.9, 93.4, 407.9, 93.3, 407.9);
    ctx.bezierCurveTo(93.0, 407.9, 92.8, 407.7, 92.7, 407.3);
    ctx.lineTo(91.5, 400.8);
    ctx.bezierCurveTo(91.5, 400.6, 91.3, 400.5, 91.2, 400.4);
    ctx.bezierCurveTo(91.0, 400.4, 90.8, 400.3, 90.6, 400.2);
    ctx.bezierCurveTo(88.2, 399.8, 86.2, 398.0, 85.5, 395.6);
    ctx.bezierCurveTo(83.5, 390.3, 89.2, 385.5, 90.1, 385.0);
    ctx.bezierCurveTo(96.7, 381.2, 102.8, 380.5, 108.2, 383.2);
    ctx.bezierCurveTo(108.7, 383.4, 112.9, 385.6, 112.6, 390.4);
    ctx.bezierCurveTo(112.3, 395.8, 107.7, 399.9, 103.4, 401.1);
    ctx.bezierCurveTo(101.3, 401.7, 99.1, 401.8, 96.9, 401.3);
    ctx.lineTo(94.0, 407.5);
    ctx.bezierCurveTo(93.9, 407.7, 93.8, 407.8, 93.7, 407.9);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(94.7, 383.9);
    ctx.bezierCurveTo(93.3, 384.5, 91.9, 385.1, 90.6, 385.9);
    ctx.bezierCurveTo(90.6, 385.9, 84.5, 390.4, 86.4, 395.4);
    ctx.bezierCurveTo(87.0, 397.5, 88.8, 399.1, 90.9, 399.4);
    ctx.bezierCurveTo(91.1, 399.5, 91.3, 399.6, 91.5, 399.6);
    ctx.bezierCurveTo(92.0, 399.8, 92.3, 400.1, 92.4, 400.6);
    ctx.lineTo(93.5, 406.5);
    ctx.lineTo(96.1, 400.9);
    ctx.bezierCurveTo(96.3, 400.6, 96.7, 400.4, 97.1, 400.5);
    ctx.bezierCurveTo(99.1, 401.0, 101.2, 400.9, 103.2, 400.4);
    ctx.bezierCurveTo(107.2, 399.2, 111.3, 395.4, 111.7, 390.5);
    ctx.bezierCurveTo(111.8, 387.8, 110.3, 385.3, 107.8, 384.1);
    ctx.bezierCurveTo(103.8, 382.1, 99.4, 382.1, 94.7, 383.9);
    ctx.lineTo(94.7, 383.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(91.5, 393.1);
    ctx.bezierCurveTo(92.0, 393.0, 92.5, 393.2, 92.7, 393.7);
    ctx.bezierCurveTo(92.9, 394.1, 92.6, 394.7, 92.1, 394.9);
    ctx.bezierCurveTo(91.6, 395.0, 91.1, 394.8, 90.9, 394.3);
    ctx.bezierCurveTo(90.7, 393.9, 91.0, 393.3, 91.5, 393.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(98.7, 391.9);
    ctx.bezierCurveTo(99.1, 391.7, 99.7, 391.9, 99.9, 392.4);
    ctx.bezierCurveTo(100.1, 392.9, 99.8, 393.4, 99.3, 393.6);
    ctx.bezierCurveTo(98.8, 393.8, 98.3, 393.6, 98.1, 393.1);
    ctx.bezierCurveTo(97.9, 392.6, 98.2, 392.1, 98.7, 391.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(105.2, 390.4);
    ctx.bezierCurveTo(105.7, 390.2, 106.3, 390.4, 106.4, 390.9);
    ctx.bezierCurveTo(106.6, 391.4, 106.4, 391.9, 105.9, 392.1);
    ctx.bezierCurveTo(105.4, 392.3, 104.8, 392.0, 104.7, 391.6);
    ctx.bezierCurveTo(104.5, 391.1, 104.7, 390.6, 105.2, 390.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(275.5, 272.9);
    ctx.bezierCurveTo(275.4, 273.0, 275.2, 273.0, 275.1, 272.9);
    ctx.bezierCurveTo(274.7, 272.9, 274.3, 272.6, 274.3, 272.2);
    ctx.lineTo(272.6, 263.4);
    ctx.bezierCurveTo(272.6, 263.2, 272.4, 263.0, 272.2, 262.9);
    ctx.bezierCurveTo(272.0, 262.9, 271.8, 262.8, 271.5, 262.7);
    ctx.bezierCurveTo(269.5, 262.1, 266.5, 261.3, 264.7, 256.5);
    ctx.bezierCurveTo(261.9, 249.4, 269.5, 243.0, 270.7, 242.3);
    ctx.bezierCurveTo(279.7, 237.1, 287.8, 236.3, 295.0, 239.8);
    ctx.bezierCurveTo(295.7, 240.1, 301.3, 243.1, 300.9, 249.5);
    ctx.bezierCurveTo(300.4, 256.7, 294.3, 262.2, 288.6, 263.9);
    ctx.bezierCurveTo(285.8, 264.7, 282.8, 264.7, 279.9, 264.1);
    ctx.lineTo(276.0, 272.4);
    ctx.bezierCurveTo(275.9, 272.6, 275.7, 272.8, 275.5, 272.9);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(276.8, 240.8);
    ctx.bezierCurveTo(274.9, 241.5, 273.1, 242.4, 271.3, 243.4);
    ctx.bezierCurveTo(271.3, 243.4, 263.2, 249.4, 265.8, 256.1);
    ctx.bezierCurveTo(267.4, 260.3, 269.9, 261.1, 271.8, 261.5);
    ctx.bezierCurveTo(272.1, 261.6, 272.3, 261.7, 272.6, 261.8);
    ctx.bezierCurveTo(273.2, 262.0, 273.7, 262.5, 273.8, 263.1);
    ctx.lineTo(275.3, 271.0);
    ctx.lineTo(278.8, 263.6);
    ctx.bezierCurveTo(279.0, 263.1, 279.5, 262.8, 280.0, 262.9);
    ctx.bezierCurveTo(282.7, 263.6, 285.5, 263.6, 288.2, 262.8);
    ctx.bezierCurveTo(293.5, 261.2, 299.2, 256.2, 299.6, 249.6);
    ctx.bezierCurveTo(300.0, 243.9, 295.0, 241.3, 294.4, 241.1);
    ctx.bezierCurveTo(289.1, 238.4, 283.2, 238.3, 276.8, 240.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(272.6, 253.2);
    ctx.bezierCurveTo(273.3, 252.9, 274.0, 253.2, 274.2, 253.9);
    ctx.bezierCurveTo(274.5, 254.5, 274.1, 255.2, 273.5, 255.5);
    ctx.bezierCurveTo(272.8, 255.7, 272.1, 255.4, 271.8, 254.8);
    ctx.bezierCurveTo(271.6, 254.1, 271.9, 253.4, 272.6, 253.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(282.2, 251.5);
    ctx.bezierCurveTo(282.9, 251.2, 283.6, 251.6, 283.8, 252.2);
    ctx.bezierCurveTo(284.1, 252.8, 283.8, 253.6, 283.1, 253.8);
    ctx.bezierCurveTo(282.4, 254.1, 281.7, 253.7, 281.5, 253.1);
    ctx.bezierCurveTo(281.2, 252.5, 281.5, 251.7, 282.2, 251.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(291.0, 249.5);
    ctx.bezierCurveTo(291.7, 249.2, 292.4, 249.5, 292.6, 250.2);
    ctx.bezierCurveTo(292.9, 250.8, 292.6, 251.5, 291.9, 251.8);
    ctx.bezierCurveTo(291.2, 252.0, 290.5, 251.7, 290.3, 251.1);
    ctx.bezierCurveTo(290.0, 250.4, 290.3, 249.7, 291.0, 249.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(320.0, 235.3);
    ctx.bezierCurveTo(319.8, 235.3, 319.7, 235.3, 319.5, 235.3);
    ctx.bezierCurveTo(319.1, 235.2, 318.8, 234.9, 318.7, 234.5);
    ctx.lineTo(317.1, 225.7);
    ctx.bezierCurveTo(317.0, 225.5, 316.9, 225.3, 316.7, 225.2);
    ctx.bezierCurveTo(316.5, 225.2, 316.2, 225.1, 315.9, 225.0);
    ctx.bezierCurveTo(313.9, 224.4, 310.9, 223.6, 309.1, 218.8);
    ctx.bezierCurveTo(306.4, 211.7, 314.0, 205.3, 315.2, 204.6);
    ctx.bezierCurveTo(324.1, 199.5, 332.3, 198.6, 339.5, 202.1);
    ctx.bezierCurveTo(340.1, 202.4, 345.8, 205.4, 345.4, 211.9);
    ctx.bezierCurveTo(344.9, 219.1, 338.8, 224.6, 333.1, 226.2);
    ctx.bezierCurveTo(330.2, 227.0, 327.2, 227.1, 324.4, 226.4);
    ctx.lineTo(320.5, 234.7);
    ctx.bezierCurveTo(320.4, 234.9, 320.2, 235.1, 320.0, 235.3);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(321.3, 203.1);
    ctx.bezierCurveTo(319.4, 203.8, 317.6, 204.7, 315.8, 205.7);
    ctx.bezierCurveTo(315.7, 205.7, 307.7, 211.7, 310.2, 218.4);
    ctx.bezierCurveTo(311.8, 222.6, 314.4, 223.4, 316.2, 223.9);
    ctx.bezierCurveTo(316.5, 223.9, 316.8, 224.0, 317.0, 224.1);
    ctx.bezierCurveTo(317.7, 224.3, 318.1, 224.8, 318.2, 225.5);
    ctx.lineTo(319.7, 233.4);
    ctx.lineTo(323.2, 225.9);
    ctx.bezierCurveTo(323.5, 225.4, 324.0, 225.1, 324.5, 225.3);
    ctx.bezierCurveTo(327.2, 225.9, 330.0, 225.9, 332.7, 225.1);
    ctx.bezierCurveTo(338.0, 223.6, 343.7, 218.5, 344.0, 211.9);
    ctx.bezierCurveTo(344.4, 206.3, 339.5, 203.6, 338.9, 203.4);
    ctx.bezierCurveTo(333.6, 200.7, 327.7, 200.7, 321.3, 203.1);
    ctx.lineTo(321.3, 203.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(317.1, 215.5);
    ctx.bezierCurveTo(317.8, 215.2, 318.5, 215.6, 318.7, 216.2);
    ctx.bezierCurveTo(319.0, 216.8, 318.6, 217.6, 318.0, 217.8);
    ctx.bezierCurveTo(317.3, 218.1, 316.6, 217.8, 316.3, 217.1);
    ctx.bezierCurveTo(316.1, 216.5, 316.4, 215.7, 317.1, 215.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(326.7, 213.8);
    ctx.bezierCurveTo(327.4, 213.6, 328.1, 213.9, 328.3, 214.5);
    ctx.bezierCurveTo(328.6, 215.2, 328.2, 215.9, 327.6, 216.1);
    ctx.bezierCurveTo(326.9, 216.4, 326.2, 216.1, 325.9, 215.4);
    ctx.bezierCurveTo(325.7, 214.8, 326.0, 214.1, 326.7, 213.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(335.5, 211.8);
    ctx.bezierCurveTo(336.2, 211.5, 336.9, 211.9, 337.2, 212.5);
    ctx.bezierCurveTo(337.4, 213.1, 337.1, 213.9, 336.4, 214.1);
    ctx.bezierCurveTo(335.7, 214.4, 335.0, 214.1, 334.8, 213.4);
    ctx.bezierCurveTo(334.5, 212.8, 334.9, 212.1, 335.5, 211.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(57.3, 252.9);
    ctx.bezierCurveTo(57.2, 252.9, 57.0, 252.9, 56.9, 252.9);
    ctx.bezierCurveTo(56.5, 252.9, 56.1, 252.6, 56.0, 252.1);
    ctx.lineTo(54.4, 243.3);
    ctx.bezierCurveTo(54.4, 243.1, 54.2, 242.9, 54.0, 242.9);
    ctx.bezierCurveTo(53.8, 242.9, 53.5, 242.7, 53.2, 242.6);
    ctx.bezierCurveTo(51.2, 242.1, 48.2, 241.2, 46.4, 236.4);
    ctx.bezierCurveTo(43.7, 229.3, 51.3, 222.9, 52.5, 222.2);
    ctx.bezierCurveTo(61.4, 217.1, 69.6, 216.2, 76.8, 219.8);
    ctx.bezierCurveTo(77.5, 220.1, 83.1, 223.1, 82.7, 229.5);
    ctx.bezierCurveTo(82.2, 236.7, 76.1, 242.2, 70.4, 243.8);
    ctx.bezierCurveTo(67.6, 244.6, 64.6, 244.7, 61.7, 244.0);
    ctx.lineTo(57.8, 252.3);
    ctx.bezierCurveTo(57.7, 252.6, 57.6, 252.8, 57.3, 252.9);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(58.6, 220.7);
    ctx.bezierCurveTo(56.7, 221.5, 54.9, 222.3, 53.1, 223.3);
    ctx.bezierCurveTo(53.1, 223.3, 45.0, 229.3, 47.6, 236.0);
    ctx.bezierCurveTo(49.2, 240.3, 51.7, 241.0, 53.6, 241.5);
    ctx.bezierCurveTo(53.9, 241.6, 54.1, 241.7, 54.4, 241.7);
    ctx.bezierCurveTo(55.0, 241.9, 55.5, 242.4, 55.6, 243.1);
    ctx.lineTo(57.1, 251.0);
    ctx.lineTo(60.6, 243.5);
    ctx.bezierCurveTo(60.8, 243.0, 61.3, 242.8, 61.8, 242.9);
    ctx.bezierCurveTo(64.5, 243.5, 67.3, 243.5, 70.0, 242.8);
    ctx.bezierCurveTo(75.3, 241.2, 81.0, 236.1, 81.4, 229.6);
    ctx.bezierCurveTo(81.8, 223.9, 76.8, 221.3, 76.2, 221.0);
    ctx.bezierCurveTo(70.9, 218.4, 65.0, 218.3, 58.6, 220.7);
    ctx.lineTo(58.6, 220.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(54.4, 233.1);
    ctx.bezierCurveTo(55.1, 232.9, 55.8, 233.2, 56.0, 233.8);
    ctx.bezierCurveTo(56.3, 234.5, 55.9, 235.2, 55.3, 235.4);
    ctx.bezierCurveTo(54.6, 235.7, 53.9, 235.4, 53.6, 234.7);
    ctx.bezierCurveTo(53.4, 234.1, 53.7, 233.4, 54.4, 233.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(64.0, 231.4);
    ctx.bezierCurveTo(64.7, 231.2, 65.4, 231.5, 65.6, 232.1);
    ctx.bezierCurveTo(65.9, 232.8, 65.5, 233.5, 64.9, 233.8);
    ctx.bezierCurveTo(64.2, 234.0, 63.5, 233.7, 63.2, 233.1);
    ctx.bezierCurveTo(63.0, 232.4, 63.3, 231.7, 64.0, 231.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(72.8, 229.4);
    ctx.bezierCurveTo(73.5, 229.2, 74.2, 229.5, 74.5, 230.1);
    ctx.bezierCurveTo(74.7, 230.8, 74.4, 231.5, 73.7, 231.7);
    ctx.bezierCurveTo(73.0, 232.0, 72.3, 231.7, 72.1, 231.0);
    ctx.bezierCurveTo(71.8, 230.4, 72.2, 229.7, 72.8, 229.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(361.9, 335.4);
    ctx.bezierCurveTo(361.7, 335.4, 361.6, 335.4, 361.4, 335.4);
    ctx.bezierCurveTo(361.0, 335.4, 360.7, 335.1, 360.6, 334.7);
    ctx.lineTo(358.9, 325.8);
    ctx.bezierCurveTo(358.9, 325.6, 358.8, 325.5, 358.6, 325.4);
    ctx.bezierCurveTo(358.3, 325.3, 358.1, 325.2, 357.8, 325.2);
    ctx.bezierCurveTo(355.8, 324.6, 352.8, 323.7, 351.0, 319.0);
    ctx.bezierCurveTo(348.3, 311.9, 355.8, 305.5, 357.1, 304.7);
    ctx.bezierCurveTo(366.0, 299.6, 374.1, 298.7, 381.4, 302.3);
    ctx.bezierCurveTo(382.0, 302.6, 387.7, 305.6, 387.3, 312.0);
    ctx.bezierCurveTo(386.8, 319.2, 380.7, 324.7, 374.9, 326.4);
    ctx.bezierCurveTo(372.1, 327.2, 369.1, 327.2, 366.3, 326.6);
    ctx.lineTo(362.4, 334.8);
    ctx.bezierCurveTo(362.3, 335.1, 362.1, 335.3, 361.9, 335.4);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(363.2, 303.2);
    ctx.bezierCurveTo(361.3, 303.9, 359.4, 304.8, 357.7, 305.8);
    ctx.bezierCurveTo(357.6, 305.8, 349.6, 311.8, 352.1, 318.5);
    ctx.bezierCurveTo(353.7, 322.7, 356.3, 323.5, 358.1, 324.0);
    ctx.bezierCurveTo(358.4, 324.0, 358.7, 324.1, 358.9, 324.2);
    ctx.bezierCurveTo(359.5, 324.4, 360.0, 324.9, 360.1, 325.6);
    ctx.lineTo(361.6, 333.5);
    ctx.lineTo(365.1, 326.0);
    ctx.bezierCurveTo(365.3, 325.5, 365.9, 325.3, 366.4, 325.4);
    ctx.bezierCurveTo(369.1, 326.0, 371.9, 326.0, 374.5, 325.2);
    ctx.bezierCurveTo(379.9, 323.7, 385.5, 318.6, 385.9, 312.1);
    ctx.bezierCurveTo(386.3, 306.4, 381.3, 303.8, 380.7, 303.5);
    ctx.bezierCurveTo(375.5, 300.9, 369.6, 300.8, 363.2, 303.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(358.9, 315.6);
    ctx.bezierCurveTo(359.6, 315.4, 360.3, 315.7, 360.6, 316.4);
    ctx.bezierCurveTo(360.8, 317.0, 360.5, 317.7, 359.8, 318.0);
    ctx.bezierCurveTo(359.1, 318.2, 358.4, 317.9, 358.2, 317.3);
    ctx.bezierCurveTo(357.9, 316.6, 358.3, 315.9, 358.9, 315.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(368.5, 314.0);
    ctx.bezierCurveTo(369.2, 313.7, 369.9, 314.0, 370.2, 314.7);
    ctx.bezierCurveTo(370.4, 315.3, 370.1, 316.0, 369.4, 316.3);
    ctx.bezierCurveTo(368.8, 316.5, 368.0, 316.2, 367.8, 315.6);
    ctx.bezierCurveTo(367.5, 314.9, 367.9, 314.2, 368.5, 314.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(377.3, 311.9);
    ctx.bezierCurveTo(378.0, 311.7, 378.7, 312.0, 379.0, 312.6);
    ctx.bezierCurveTo(379.2, 313.3, 378.9, 314.0, 378.2, 314.3);
    ctx.bezierCurveTo(377.6, 314.5, 376.8, 314.2, 376.6, 313.6);
    ctx.bezierCurveTo(376.3, 312.9, 376.7, 312.2, 377.3, 311.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(289.5, 309.5);
    ctx.bezierCurveTo(289.4, 309.6, 289.3, 309.6, 289.1, 309.5);
    ctx.bezierCurveTo(288.8, 309.5, 288.6, 309.3, 288.5, 309.0);
    ctx.lineTo(287.3, 302.4);
    ctx.bezierCurveTo(287.3, 302.3, 287.2, 302.1, 287.0, 302.1);
    ctx.bezierCurveTo(286.9, 302.1, 286.7, 302.0, 286.4, 301.9);
    ctx.bezierCurveTo(284.0, 301.4, 282.1, 299.7, 281.4, 297.3);
    ctx.bezierCurveTo(279.4, 292.0, 285.0, 287.3, 285.9, 286.7);
    ctx.bezierCurveTo(292.5, 282.9, 298.6, 282.3, 304.0, 284.9);
    ctx.bezierCurveTo(304.5, 285.1, 308.7, 287.3, 308.4, 292.1);
    ctx.bezierCurveTo(308.0, 297.5, 303.5, 301.6, 299.2, 302.8);
    ctx.bezierCurveTo(297.1, 303.4, 294.9, 303.5, 292.7, 303.0);
    ctx.lineTo(289.8, 309.1);
    ctx.bezierCurveTo(289.8, 309.3, 289.6, 309.5, 289.5, 309.5);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(290.5, 285.6);
    ctx.bezierCurveTo(289.1, 286.2, 287.7, 286.8, 286.4, 287.6);
    ctx.bezierCurveTo(286.3, 287.6, 280.4, 292.1, 282.2, 297.1);
    ctx.bezierCurveTo(282.8, 299.2, 284.6, 300.7, 286.7, 301.1);
    ctx.bezierCurveTo(287.0, 301.2, 287.1, 301.2, 287.3, 301.3);
    ctx.bezierCurveTo(287.8, 301.4, 288.1, 301.8, 288.2, 302.3);
    ctx.lineTo(289.3, 308.1);
    ctx.lineTo(291.9, 302.6);
    ctx.bezierCurveTo(292.1, 302.2, 292.5, 302.0, 292.9, 302.1);
    ctx.bezierCurveTo(294.9, 302.6, 297.0, 302.6, 299.0, 302.0);
    ctx.bezierCurveTo(303.0, 300.8, 307.1, 297.1, 307.4, 292.2);
    ctx.bezierCurveTo(307.5, 289.5, 306.0, 287.0, 303.6, 285.8);
    ctx.bezierCurveTo(299.6, 283.8, 295.2, 283.8, 290.5, 285.6);
    ctx.lineTo(290.5, 285.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(287.3, 294.8);
    ctx.bezierCurveTo(287.8, 294.7, 288.3, 294.9, 288.5, 295.4);
    ctx.bezierCurveTo(288.7, 295.8, 288.4, 296.4, 287.9, 296.6);
    ctx.bezierCurveTo(287.4, 296.7, 286.9, 296.5, 286.7, 296.0);
    ctx.bezierCurveTo(286.5, 295.6, 286.8, 295.0, 287.3, 294.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(294.4, 293.6);
    ctx.bezierCurveTo(294.9, 293.4, 295.5, 293.6, 295.7, 294.1);
    ctx.bezierCurveTo(295.8, 294.6, 295.6, 295.1, 295.1, 295.3);
    ctx.bezierCurveTo(294.6, 295.5, 294.1, 295.3, 293.9, 294.8);
    ctx.bezierCurveTo(293.7, 294.3, 294.0, 293.8, 294.4, 293.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(301.0, 292.1);
    ctx.bezierCurveTo(301.5, 291.9, 302.0, 292.1, 302.2, 292.6);
    ctx.bezierCurveTo(302.4, 293.1, 302.1, 293.6, 301.7, 293.8);
    ctx.bezierCurveTo(301.2, 294.0, 300.6, 293.8, 300.4, 293.3);
    ctx.bezierCurveTo(300.3, 292.8, 300.5, 292.3, 301.0, 292.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(320.7, 330.9);
    ctx.bezierCurveTo(320.6, 330.9, 320.5, 330.9, 320.4, 330.9);
    ctx.bezierCurveTo(320.1, 330.9, 319.8, 330.7, 319.7, 330.4);
    ctx.lineTo(318.5, 323.8);
    ctx.bezierCurveTo(318.5, 323.6, 318.4, 323.5, 318.2, 323.5);
    ctx.bezierCurveTo(318.1, 323.5, 317.9, 323.3, 317.7, 323.3);
    ctx.bezierCurveTo(315.2, 322.8, 313.3, 321.0, 312.6, 318.7);
    ctx.bezierCurveTo(310.6, 313.4, 316.2, 308.7, 317.1, 308.1);
    ctx.bezierCurveTo(323.8, 304.3, 329.8, 303.6, 335.2, 306.3);
    ctx.bezierCurveTo(335.7, 306.5, 339.9, 308.7, 339.6, 313.5);
    ctx.bezierCurveTo(339.2, 318.9, 334.7, 323.0, 330.4, 324.2);
    ctx.bezierCurveTo(328.3, 324.8, 326.1, 324.8, 324.0, 324.3);
    ctx.lineTo(321.1, 330.5);
    ctx.bezierCurveTo(321.0, 330.7, 320.9, 330.8, 320.7, 330.9);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(321.7, 307.0);
    ctx.bezierCurveTo(320.3, 307.5, 318.9, 308.2, 317.6, 309.0);
    ctx.bezierCurveTo(317.6, 309.0, 311.6, 313.4, 313.5, 318.4);
    ctx.bezierCurveTo(314.1, 320.5, 315.8, 322.1, 318.0, 322.5);
    ctx.bezierCurveTo(318.2, 322.5, 318.4, 322.6, 318.5, 322.6);
    ctx.bezierCurveTo(319.0, 322.8, 319.3, 323.2, 319.4, 323.6);
    ctx.lineTo(320.5, 329.5);
    ctx.lineTo(323.2, 323.9);
    ctx.bezierCurveTo(323.3, 323.6, 323.7, 323.4, 324.1, 323.5);
    ctx.bezierCurveTo(326.1, 324.0, 328.2, 323.9, 330.2, 323.4);
    ctx.bezierCurveTo(334.2, 322.2, 338.3, 318.5, 338.7, 313.6);
    ctx.bezierCurveTo(338.8, 310.9, 337.2, 308.4, 334.8, 307.2);
    ctx.bezierCurveTo(330.8, 305.2, 326.4, 305.2, 321.7, 307.0);
    ctx.lineTo(321.7, 307.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(318.5, 316.2);
    ctx.bezierCurveTo(319.0, 316.0, 319.5, 316.3, 319.7, 316.7);
    ctx.bezierCurveTo(319.9, 317.2, 319.6, 317.7, 319.2, 317.9);
    ctx.bezierCurveTo(318.7, 318.1, 318.1, 317.9, 317.9, 317.4);
    ctx.bezierCurveTo(317.8, 316.9, 318.0, 316.4, 318.5, 316.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(325.7, 315.0);
    ctx.bezierCurveTo(326.2, 314.8, 326.7, 315.0, 326.9, 315.5);
    ctx.bezierCurveTo(327.1, 316.0, 326.8, 316.5, 326.3, 316.7);
    ctx.bezierCurveTo(325.8, 316.9, 325.3, 316.6, 325.1, 316.2);
    ctx.bezierCurveTo(324.9, 315.7, 325.2, 315.1, 325.7, 315.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(332.2, 313.5);
    ctx.bezierCurveTo(332.7, 313.3, 333.3, 313.5, 333.4, 314.0);
    ctx.bezierCurveTo(333.6, 314.5, 333.4, 315.0, 332.9, 315.2);
    ctx.bezierCurveTo(332.4, 315.4, 331.8, 315.1, 331.7, 314.7);
    ctx.bezierCurveTo(331.5, 314.2, 331.7, 313.6, 332.2, 313.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(345.2, 403.2);
    ctx.bezierCurveTo(345.1, 403.2, 345.0, 403.2, 344.9, 403.2);
    ctx.bezierCurveTo(344.6, 403.2, 344.3, 403.0, 344.3, 402.7);
    ctx.lineTo(343.0, 396.1);
    ctx.bezierCurveTo(343.0, 396.0, 342.8, 395.8, 342.7, 395.8);
    ctx.bezierCurveTo(342.6, 395.7, 342.4, 395.7, 342.1, 395.6);
    ctx.bezierCurveTo(339.7, 395.1, 337.8, 393.3, 337.1, 391.0);
    ctx.bezierCurveTo(335.1, 385.7, 340.7, 381.0, 341.6, 380.4);
    ctx.bezierCurveTo(348.2, 376.6, 354.3, 376.0, 359.7, 378.6);
    ctx.bezierCurveTo(360.2, 378.8, 364.4, 381.0, 364.1, 385.8);
    ctx.bezierCurveTo(363.7, 391.2, 359.2, 395.3, 354.9, 396.5);
    ctx.bezierCurveTo(352.8, 397.1, 350.6, 397.1, 348.4, 396.6);
    ctx.lineTo(345.5, 402.8);
    ctx.bezierCurveTo(345.5, 403.0, 345.4, 403.1, 345.2, 403.2);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(346.2, 379.3);
    ctx.bezierCurveTo(344.8, 379.8, 343.5, 380.5, 342.1, 381.3);
    ctx.bezierCurveTo(342.1, 381.3, 336.1, 385.7, 338.0, 390.7);
    ctx.bezierCurveTo(338.6, 392.8, 340.3, 394.4, 342.5, 394.8);
    ctx.bezierCurveTo(342.7, 394.8, 342.9, 394.9, 343.1, 394.9);
    ctx.bezierCurveTo(343.5, 395.1, 343.9, 395.5, 344.0, 395.9);
    ctx.lineTo(345.1, 401.8);
    ctx.lineTo(347.7, 396.2);
    ctx.bezierCurveTo(347.9, 395.9, 348.3, 395.7, 348.6, 395.8);
    ctx.bezierCurveTo(350.6, 396.3, 352.7, 396.2, 354.7, 395.7);
    ctx.bezierCurveTo(358.7, 394.5, 362.9, 390.8, 363.2, 385.9);
    ctx.bezierCurveTo(363.3, 383.2, 361.8, 380.7, 359.3, 379.5);
    ctx.bezierCurveTo(355.4, 377.5, 351.0, 377.5, 346.2, 379.3);
    ctx.lineTo(346.2, 379.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(343.0, 388.5);
    ctx.bezierCurveTo(343.5, 388.3, 344.1, 388.5, 344.2, 389.0);
    ctx.bezierCurveTo(344.4, 389.5, 344.2, 390.0, 343.7, 390.2);
    ctx.bezierCurveTo(343.2, 390.4, 342.7, 390.2, 342.5, 389.7);
    ctx.bezierCurveTo(342.3, 389.2, 342.5, 388.7, 343.0, 388.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(350.2, 387.2);
    ctx.bezierCurveTo(350.7, 387.1, 351.2, 387.3, 351.4, 387.8);
    ctx.bezierCurveTo(351.6, 388.2, 351.3, 388.8, 350.8, 389.0);
    ctx.bezierCurveTo(350.4, 389.2, 349.8, 388.9, 349.6, 388.4);
    ctx.bezierCurveTo(349.5, 388.0, 349.7, 387.4, 350.2, 387.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(356.7, 385.7);
    ctx.bezierCurveTo(357.2, 385.6, 357.8, 385.8, 358.0, 386.3);
    ctx.bezierCurveTo(358.1, 386.7, 357.9, 387.3, 357.4, 387.5);
    ctx.bezierCurveTo(356.9, 387.6, 356.4, 387.4, 356.2, 386.9);
    ctx.bezierCurveTo(356.0, 386.5, 356.3, 385.9, 356.7, 385.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(392.2, 213.1);
    ctx.bezierCurveTo(392.1, 213.2, 392.0, 213.2, 391.9, 213.1);
    ctx.bezierCurveTo(391.6, 213.1, 391.3, 212.9, 391.3, 212.6);
    ctx.lineTo(390.0, 206.0);
    ctx.bezierCurveTo(390.0, 205.9, 389.9, 205.8, 389.7, 205.7);
    ctx.bezierCurveTo(389.5, 205.7, 389.4, 205.6, 389.1, 205.5);
    ctx.bezierCurveTo(386.7, 205.1, 384.8, 203.3, 384.1, 200.9);
    ctx.bezierCurveTo(382.1, 195.6, 387.7, 190.9, 388.6, 190.3);
    ctx.bezierCurveTo(395.2, 186.5, 401.3, 185.9, 406.7, 188.5);
    ctx.bezierCurveTo(407.2, 188.7, 411.4, 191.0, 411.1, 195.8);
    ctx.bezierCurveTo(410.7, 201.1, 406.2, 205.2, 401.9, 206.4);
    ctx.bezierCurveTo(399.8, 207.0, 397.6, 207.1, 395.4, 206.6);
    ctx.lineTo(392.5, 212.8);
    ctx.bezierCurveTo(392.5, 212.9, 392.4, 213.0, 392.2, 213.1);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(393.2, 189.2);
    ctx.bezierCurveTo(391.8, 189.8, 390.4, 190.4, 389.1, 191.2);
    ctx.bezierCurveTo(389.1, 191.2, 383.1, 195.7, 385.0, 200.7);
    ctx.bezierCurveTo(385.6, 202.7, 387.3, 204.3, 389.4, 204.7);
    ctx.bezierCurveTo(389.7, 204.7, 389.9, 204.8, 390.0, 204.8);
    ctx.bezierCurveTo(390.5, 205.0, 390.8, 205.4, 390.9, 205.8);
    ctx.lineTo(392.0, 211.7);
    ctx.lineTo(394.7, 206.1);
    ctx.bezierCurveTo(394.8, 205.8, 395.2, 205.6, 395.6, 205.7);
    ctx.bezierCurveTo(397.6, 206.2, 399.7, 206.1, 401.7, 205.6);
    ctx.bezierCurveTo(405.7, 204.4, 409.8, 200.7, 410.1, 195.8);
    ctx.bezierCurveTo(410.2, 193.1, 408.7, 190.6, 406.3, 189.4);
    ctx.bezierCurveTo(402.4, 187.4, 398.0, 187.4, 393.2, 189.2);
    ctx.lineTo(393.2, 189.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(390.0, 198.4);
    ctx.bezierCurveTo(390.5, 198.2, 391.1, 198.5, 391.2, 199.0);
    ctx.bezierCurveTo(391.4, 199.4, 391.2, 200.0, 390.7, 200.2);
    ctx.bezierCurveTo(390.2, 200.3, 389.7, 200.1, 389.5, 199.6);
    ctx.bezierCurveTo(389.3, 199.2, 389.5, 198.6, 390.0, 198.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(397.2, 197.2);
    ctx.bezierCurveTo(397.7, 197.0, 398.2, 197.2, 398.4, 197.7);
    ctx.bezierCurveTo(398.6, 198.2, 398.3, 198.7, 397.8, 198.9);
    ctx.bezierCurveTo(397.4, 199.1, 396.8, 198.9, 396.6, 198.4);
    ctx.bezierCurveTo(396.4, 197.9, 396.7, 197.4, 397.2, 197.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(403.7, 195.7);
    ctx.bezierCurveTo(404.2, 195.5, 404.8, 195.7, 405.0, 196.2);
    ctx.bezierCurveTo(405.1, 196.7, 404.9, 197.2, 404.4, 197.4);
    ctx.bezierCurveTo(403.9, 197.6, 403.4, 197.4, 403.2, 196.9);
    ctx.bezierCurveTo(403.0, 196.4, 403.3, 195.9, 403.7, 195.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(393.3, 103.2);
    ctx.bezierCurveTo(393.2, 103.2, 393.1, 103.2, 392.9, 103.2);
    ctx.bezierCurveTo(392.6, 103.2, 392.4, 103.0, 392.3, 102.7);
    ctx.lineTo(391.1, 96.1);
    ctx.bezierCurveTo(391.1, 95.9, 390.9, 95.8, 390.8, 95.8);
    ctx.bezierCurveTo(390.7, 95.7, 390.5, 95.6, 390.2, 95.6);
    ctx.bezierCurveTo(387.8, 95.1, 385.9, 93.3, 385.2, 91.0);
    ctx.bezierCurveTo(383.2, 85.7, 388.8, 81.0, 389.7, 80.4);
    ctx.bezierCurveTo(396.4, 76.6, 402.4, 75.9, 407.8, 78.6);
    ctx.bezierCurveTo(408.3, 78.8, 412.5, 81.0, 412.2, 85.8);
    ctx.bezierCurveTo(411.8, 91.2, 407.3, 95.2, 403.0, 96.5);
    ctx.bezierCurveTo(400.9, 97.1, 398.7, 97.1, 396.5, 96.6);
    ctx.lineTo(393.6, 102.8);
    ctx.bezierCurveTo(393.6, 103.0, 393.5, 103.1, 393.3, 103.2);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(394.3, 79.3);
    ctx.bezierCurveTo(392.9, 79.8, 391.5, 80.5, 390.2, 81.3);
    ctx.bezierCurveTo(390.2, 81.3, 384.2, 85.7, 386.0, 90.7);
    ctx.bezierCurveTo(386.7, 92.8, 388.4, 94.4, 390.5, 94.8);
    ctx.bezierCurveTo(390.8, 94.8, 391.0, 94.9, 391.1, 94.9);
    ctx.bezierCurveTo(391.6, 95.1, 391.9, 95.5, 392.0, 95.9);
    ctx.lineTo(393.1, 101.8);
    ctx.lineTo(395.7, 96.2);
    ctx.bezierCurveTo(395.9, 95.9, 396.3, 95.7, 396.7, 95.8);
    ctx.bezierCurveTo(398.7, 96.3, 400.8, 96.2, 402.8, 95.7);
    ctx.bezierCurveTo(406.8, 94.5, 410.9, 90.8, 411.2, 85.9);
    ctx.bezierCurveTo(411.3, 83.2, 409.8, 80.7, 407.4, 79.5);
    ctx.bezierCurveTo(403.4, 77.5, 399.0, 77.5, 394.3, 79.3);
    ctx.lineTo(394.3, 79.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(391.1, 88.5);
    ctx.bezierCurveTo(391.6, 88.4, 392.1, 88.6, 392.3, 89.1);
    ctx.bezierCurveTo(392.5, 89.5, 392.2, 90.1, 391.8, 90.3);
    ctx.bezierCurveTo(391.3, 90.4, 390.7, 90.2, 390.5, 89.7);
    ctx.bezierCurveTo(390.4, 89.3, 390.6, 88.7, 391.1, 88.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(398.3, 87.3);
    ctx.bezierCurveTo(398.7, 87.1, 399.3, 87.3, 399.5, 87.8);
    ctx.bezierCurveTo(399.7, 88.3, 399.4, 88.8, 398.9, 89.0);
    ctx.bezierCurveTo(398.4, 89.2, 397.9, 89.0, 397.7, 88.5);
    ctx.bezierCurveTo(397.5, 88.0, 397.8, 87.5, 398.3, 87.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(404.8, 85.8);
    ctx.bezierCurveTo(405.3, 85.6, 405.8, 85.8, 406.0, 86.3);
    ctx.bezierCurveTo(406.2, 86.8, 405.9, 87.3, 405.5, 87.5);
    ctx.bezierCurveTo(405.0, 87.7, 404.4, 87.5, 404.2, 87.0);
    ctx.bezierCurveTo(404.1, 86.5, 404.3, 86.0, 404.8, 85.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(392.2, 398.2);
    ctx.bezierCurveTo(392.1, 398.2, 392.0, 398.2, 391.9, 398.2);
    ctx.bezierCurveTo(391.6, 398.2, 391.3, 398.0, 391.3, 397.7);
    ctx.lineTo(390.0, 391.1);
    ctx.bezierCurveTo(390.0, 391.0, 389.9, 390.8, 389.7, 390.8);
    ctx.bezierCurveTo(389.5, 390.8, 389.4, 390.7, 389.1, 390.6);
    ctx.bezierCurveTo(386.7, 390.1, 384.8, 388.3, 384.1, 386.0);
    ctx.bezierCurveTo(382.1, 380.7, 387.7, 376.0, 388.6, 375.4);
    ctx.bezierCurveTo(395.2, 371.6, 401.3, 371.0, 406.7, 373.6);
    ctx.bezierCurveTo(407.2, 373.8, 411.4, 376.0, 411.1, 380.8);
    ctx.bezierCurveTo(410.7, 386.2, 406.2, 390.3, 401.9, 391.5);
    ctx.bezierCurveTo(399.8, 392.1, 397.6, 392.1, 395.4, 391.7);
    ctx.lineTo(392.5, 397.8);
    ctx.bezierCurveTo(392.5, 398.0, 392.4, 398.1, 392.2, 398.2);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(393.2, 374.3);
    ctx.bezierCurveTo(391.8, 374.8, 390.4, 375.5, 389.1, 376.2);
    ctx.bezierCurveTo(389.1, 376.2, 383.1, 380.7, 385.0, 385.6);
    ctx.bezierCurveTo(385.6, 387.7, 387.3, 389.3, 389.4, 389.7);
    ctx.bezierCurveTo(389.7, 389.8, 389.9, 389.8, 390.0, 389.9);
    ctx.bezierCurveTo(390.5, 390.0, 390.8, 390.4, 390.9, 390.9);
    ctx.lineTo(392.0, 396.7);
    ctx.lineTo(394.7, 391.2);
    ctx.bezierCurveTo(394.8, 390.8, 395.2, 390.6, 395.6, 390.7);
    ctx.bezierCurveTo(397.6, 391.2, 399.7, 391.2, 401.7, 390.6);
    ctx.bezierCurveTo(405.7, 389.4, 409.8, 385.7, 410.1, 380.8);
    ctx.bezierCurveTo(410.2, 378.1, 408.7, 375.6, 406.3, 374.4);
    ctx.bezierCurveTo(402.4, 372.5, 398.0, 372.5, 393.2, 374.3);
    ctx.lineTo(393.2, 374.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(390.0, 383.5);
    ctx.bezierCurveTo(390.5, 383.3, 391.1, 383.6, 391.2, 384.0);
    ctx.bezierCurveTo(391.4, 384.5, 391.2, 385.0, 390.7, 385.2);
    ctx.bezierCurveTo(390.2, 385.4, 389.7, 385.2, 389.5, 384.7);
    ctx.bezierCurveTo(389.3, 384.2, 389.5, 383.7, 390.0, 383.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(397.2, 382.3);
    ctx.bezierCurveTo(397.7, 382.1, 398.2, 382.3, 398.4, 382.8);
    ctx.bezierCurveTo(398.6, 383.3, 398.3, 383.8, 397.8, 384.0);
    ctx.bezierCurveTo(397.4, 384.2, 396.8, 383.9, 396.6, 383.5);
    ctx.bezierCurveTo(396.4, 383.0, 396.7, 382.5, 397.2, 382.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(403.7, 380.8);
    ctx.bezierCurveTo(404.2, 380.6, 404.8, 380.8, 404.9, 381.3);
    ctx.bezierCurveTo(405.1, 381.8, 404.9, 382.3, 404.4, 382.5);
    ctx.bezierCurveTo(403.9, 382.7, 403.4, 382.4, 403.2, 382.0);
    ctx.bezierCurveTo(403.0, 381.5, 403.2, 380.9, 403.7, 380.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(275.4, 411.3);
    ctx.bezierCurveTo(275.3, 411.3, 275.2, 411.3, 275.1, 411.3);
    ctx.bezierCurveTo(274.8, 411.3, 274.5, 411.1, 274.4, 410.8);
    ctx.lineTo(273.2, 404.2);
    ctx.bezierCurveTo(273.2, 404.1, 273.1, 403.9, 272.9, 403.9);
    ctx.bezierCurveTo(272.8, 403.9, 272.6, 403.8, 272.4, 403.7);
    ctx.bezierCurveTo(269.9, 403.2, 268.0, 401.4, 267.3, 399.1);
    ctx.bezierCurveTo(265.3, 393.8, 270.9, 389.1, 271.8, 388.5);
    ctx.bezierCurveTo(278.5, 384.7, 284.5, 384.1, 289.9, 386.7);
    ctx.bezierCurveTo(290.4, 386.9, 294.6, 389.1, 294.3, 393.9);
    ctx.bezierCurveTo(293.9, 399.3, 289.4, 403.4, 285.1, 404.6);
    ctx.bezierCurveTo(283.0, 405.2, 280.8, 405.2, 278.7, 404.7);
    ctx.lineTo(275.8, 410.9);
    ctx.bezierCurveTo(275.7, 411.1, 275.6, 411.2, 275.4, 411.3);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(276.4, 387.4);
    ctx.bezierCurveTo(275.0, 387.9, 273.6, 388.6, 272.3, 389.3);
    ctx.bezierCurveTo(272.3, 389.3, 266.3, 393.8, 268.2, 398.8);
    ctx.bezierCurveTo(268.8, 400.9, 270.5, 402.5, 272.7, 402.8);
    ctx.bezierCurveTo(272.9, 402.9, 273.1, 403.0, 273.2, 403.0);
    ctx.bezierCurveTo(273.7, 403.2, 274.0, 403.5, 274.1, 404.0);
    ctx.lineTo(275.2, 409.9);
    ctx.lineTo(277.9, 404.3);
    ctx.bezierCurveTo(278.0, 403.9, 278.4, 403.8, 278.8, 403.8);
    ctx.bezierCurveTo(280.8, 404.3, 282.9, 404.3, 284.9, 403.8);
    ctx.bezierCurveTo(288.9, 402.6, 293.0, 398.8, 293.4, 393.9);
    ctx.bezierCurveTo(293.5, 391.2, 291.9, 388.7, 289.5, 387.6);
    ctx.bezierCurveTo(285.5, 385.6, 281.1, 385.6, 276.4, 387.4);
    ctx.lineTo(276.4, 387.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(273.2, 396.6);
    ctx.bezierCurveTo(273.7, 396.4, 274.2, 396.7, 274.4, 397.1);
    ctx.bezierCurveTo(274.6, 397.6, 274.4, 398.1, 273.9, 398.3);
    ctx.bezierCurveTo(273.4, 398.5, 272.8, 398.3, 272.6, 397.8);
    ctx.bezierCurveTo(272.5, 397.3, 272.7, 396.8, 273.2, 396.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(280.4, 395.4);
    ctx.bezierCurveTo(280.9, 395.2, 281.4, 395.4, 281.6, 395.9);
    ctx.bezierCurveTo(281.8, 396.4, 281.5, 396.9, 281.0, 397.1);
    ctx.bezierCurveTo(280.5, 397.3, 280.0, 397.1, 279.8, 396.6);
    ctx.bezierCurveTo(279.6, 396.1, 279.9, 395.6, 280.4, 395.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(286.9, 393.9);
    ctx.bezierCurveTo(287.4, 393.7, 287.9, 393.9, 288.1, 394.4);
    ctx.bezierCurveTo(288.3, 394.9, 288.1, 395.4, 287.6, 395.6);
    ctx.bezierCurveTo(287.1, 395.8, 286.5, 395.5, 286.4, 395.1);
    ctx.bezierCurveTo(286.2, 394.6, 286.4, 394.1, 286.9, 393.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(298.7, 356.8);
    ctx.bezierCurveTo(298.6, 356.8, 298.5, 356.8, 298.4, 356.8);
    ctx.bezierCurveTo(298.1, 356.8, 297.8, 356.6, 297.8, 356.2);
    ctx.lineTo(296.5, 349.7);
    ctx.bezierCurveTo(296.5, 349.5, 296.4, 349.4, 296.3, 349.3);
    ctx.bezierCurveTo(296.1, 349.3, 295.9, 349.2, 295.7, 349.2);
    ctx.bezierCurveTo(293.3, 348.7, 291.3, 346.9, 290.6, 344.6);
    ctx.bezierCurveTo(288.6, 339.3, 294.2, 334.6, 295.2, 334.0);
    ctx.bezierCurveTo(301.8, 330.2, 307.9, 329.5, 313.2, 332.2);
    ctx.bezierCurveTo(313.7, 332.4, 317.9, 334.6, 317.6, 339.4);
    ctx.bezierCurveTo(317.3, 344.8, 312.7, 348.8, 308.4, 350.1);
    ctx.bezierCurveTo(306.3, 350.7, 304.1, 350.7, 302.0, 350.2);
    ctx.lineTo(299.1, 356.4);
    ctx.bezierCurveTo(299.0, 356.6, 298.9, 356.7, 298.7, 356.8);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(299.7, 332.9);
    ctx.bezierCurveTo(298.3, 333.4, 297.0, 334.1, 295.6, 334.8);
    ctx.bezierCurveTo(295.6, 334.8, 289.6, 339.3, 291.5, 344.3);
    ctx.bezierCurveTo(292.1, 346.4, 293.9, 347.9, 296.0, 348.3);
    ctx.bezierCurveTo(296.2, 348.3, 296.4, 348.4, 296.6, 348.5);
    ctx.bezierCurveTo(297.0, 348.6, 297.4, 349.0, 297.5, 349.5);
    ctx.lineTo(298.6, 355.3);
    ctx.lineTo(301.2, 349.8);
    ctx.bezierCurveTo(301.4, 349.4, 301.8, 349.2, 302.1, 349.3);
    ctx.bezierCurveTo(304.1, 349.8, 306.2, 349.8, 308.2, 349.2);
    ctx.bezierCurveTo(312.2, 348.0, 316.4, 344.3, 316.7, 339.4);
    ctx.bezierCurveTo(316.8, 336.7, 315.3, 334.2, 312.8, 333.0);
    ctx.bezierCurveTo(308.9, 331.1, 304.5, 331.1, 299.7, 332.9);
    ctx.lineTo(299.7, 332.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(296.5, 342.1);
    ctx.bezierCurveTo(297.0, 341.9, 297.6, 342.2, 297.8, 342.6);
    ctx.bezierCurveTo(297.9, 343.1, 297.7, 343.6, 297.2, 343.8);
    ctx.bezierCurveTo(296.7, 344.0, 296.2, 343.8, 296.0, 343.3);
    ctx.bezierCurveTo(295.8, 342.8, 296.1, 342.3, 296.5, 342.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(303.7, 340.9);
    ctx.bezierCurveTo(304.2, 340.7, 304.7, 340.9, 304.9, 341.4);
    ctx.bezierCurveTo(305.1, 341.8, 304.9, 342.4, 304.4, 342.6);
    ctx.bezierCurveTo(303.9, 342.8, 303.3, 342.5, 303.1, 342.1);
    ctx.bezierCurveTo(303.0, 341.6, 303.2, 341.0, 303.7, 340.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(310.3, 339.3);
    ctx.bezierCurveTo(310.7, 339.2, 311.3, 339.4, 311.5, 339.9);
    ctx.bezierCurveTo(311.6, 340.3, 311.4, 340.9, 310.9, 341.1);
    ctx.bezierCurveTo(310.4, 341.2, 309.9, 341.0, 309.7, 340.5);
    ctx.bezierCurveTo(309.5, 340.1, 309.8, 339.5, 310.3, 339.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(276.9, 355.4);
    ctx.bezierCurveTo(277.1, 355.5, 277.3, 355.5, 277.5, 355.4);
    ctx.bezierCurveTo(278.1, 355.3, 278.5, 354.9, 278.5, 354.3);
    ctx.lineTo(279.2, 342.4);
    ctx.bezierCurveTo(279.2, 342.1, 279.4, 341.9, 279.6, 341.7);
    ctx.bezierCurveTo(279.9, 341.6, 280.2, 341.4, 280.6, 341.3);
    ctx.bezierCurveTo(283.1, 340.2, 286.9, 338.5, 288.5, 331.9);
    ctx.bezierCurveTo(290.8, 322.1, 279.9, 315.0, 278.2, 314.3);
    ctx.bezierCurveTo(265.7, 309.1, 254.9, 309.4, 246.1, 315.3);
    ctx.bezierCurveTo(245.3, 315.8, 238.4, 320.7, 240.0, 329.1);
    ctx.bezierCurveTo(241.8, 338.5, 250.7, 344.7, 258.5, 345.8);
    ctx.bezierCurveTo(262.3, 346.4, 266.2, 345.9, 269.8, 344.6);
    ctx.lineTo(276.3, 354.8);
    ctx.bezierCurveTo(276.4, 355.1, 276.6, 355.3, 276.9, 355.4);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(269.9, 313.3);
    ctx.bezierCurveTo(272.5, 313.9, 275.0, 314.8, 277.5, 315.8);
    ctx.bezierCurveTo(277.5, 315.8, 289.0, 322.3, 286.8, 331.5);
    ctx.bezierCurveTo(285.4, 337.4, 282.2, 338.8, 279.8, 339.7);
    ctx.bezierCurveTo(279.4, 339.9, 279.1, 340.1, 278.8, 340.2);
    ctx.bezierCurveTo(278.0, 340.6, 277.5, 341.3, 277.5, 342.2);
    ctx.lineTo(276.8, 352.9);
    ctx.lineTo(271.0, 343.6);
    ctx.bezierCurveTo(270.7, 343.0, 269.9, 342.8, 269.3, 343.0);
    ctx.bezierCurveTo(265.9, 344.4, 262.2, 344.8, 258.6, 344.3);
    ctx.bezierCurveTo(251.4, 343.2, 243.2, 337.5, 241.6, 328.9);
    ctx.bezierCurveTo(240.2, 321.5, 246.2, 317.2, 246.9, 316.7);
    ctx.bezierCurveTo(253.4, 312.3, 261.1, 311.2, 269.9, 313.3);
    ctx.lineTo(269.9, 313.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(275.4, 330.1);
    ctx.bezierCurveTo(275.6, 329.2, 276.5, 328.6, 277.4, 328.9);
    ctx.bezierCurveTo(278.3, 329.1, 278.9, 330.0, 278.7, 330.8);
    ctx.bezierCurveTo(278.5, 331.7, 277.6, 332.3, 276.7, 332.1);
    ctx.bezierCurveTo(275.8, 331.8, 275.2, 331.0, 275.4, 330.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(262.6, 329.5);
    ctx.bezierCurveTo(262.8, 328.7, 263.7, 328.1, 264.6, 328.3);
    ctx.bezierCurveTo(265.5, 328.5, 266.1, 329.4, 265.9, 330.3);
    ctx.bezierCurveTo(265.7, 331.2, 264.8, 331.7, 263.9, 331.5);
    ctx.bezierCurveTo(263.0, 331.3, 262.4, 330.4, 262.6, 329.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(250.8, 328.4);
    ctx.bezierCurveTo(251.0, 327.5, 251.9, 327.0, 252.8, 327.2);
    ctx.bezierCurveTo(253.7, 327.4, 254.3, 328.3, 254.1, 329.2);
    ctx.bezierCurveTo(253.9, 330.1, 253.0, 330.6, 252.1, 330.4);
    ctx.bezierCurveTo(251.2, 330.2, 250.6, 329.3, 250.8, 328.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(175.8, 323.9);
    ctx.bezierCurveTo(176.0, 323.9, 176.2, 323.9, 176.4, 323.9);
    ctx.bezierCurveTo(176.9, 323.8, 177.3, 323.3, 177.4, 322.8);
    ctx.lineTo(178.0, 310.9);
    ctx.bezierCurveTo(178.1, 310.6, 178.2, 310.3, 178.5, 310.2);
    ctx.bezierCurveTo(178.7, 310.1, 179.0, 309.9, 179.5, 309.8);
    ctx.bezierCurveTo(182.0, 308.7, 185.7, 307.0, 187.3, 300.4);
    ctx.bezierCurveTo(189.6, 290.6, 178.7, 283.5, 177.0, 282.7);
    ctx.bezierCurveTo(164.5, 277.6, 153.8, 277.9, 144.9, 283.8);
    ctx.bezierCurveTo(144.1, 284.3, 137.2, 289.2, 138.9, 297.6);
    ctx.bezierCurveTo(140.7, 307.0, 149.6, 313.2, 157.3, 314.4);
    ctx.bezierCurveTo(161.1, 314.9, 165.0, 314.5, 168.7, 313.1);
    ctx.lineTo(175.0, 323.3);
    ctx.bezierCurveTo(175.2, 323.6, 175.4, 323.8, 175.8, 323.9);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(168.8, 281.8);
    ctx.bezierCurveTo(171.4, 282.4, 173.9, 283.2, 176.4, 284.2);
    ctx.bezierCurveTo(176.4, 284.2, 187.9, 290.7, 185.7, 300.0);
    ctx.bezierCurveTo(184.3, 305.8, 181.1, 307.3, 178.7, 308.2);
    ctx.bezierCurveTo(178.3, 308.4, 178.0, 308.6, 177.7, 308.7);
    ctx.bezierCurveTo(176.9, 309.0, 176.4, 309.8, 176.4, 310.7);
    ctx.lineTo(175.7, 321.4);
    ctx.lineTo(169.9, 312.1);
    ctx.bezierCurveTo(169.6, 311.5, 168.8, 311.3, 168.2, 311.5);
    ctx.bezierCurveTo(164.8, 312.9, 161.1, 313.3, 157.5, 312.8);
    ctx.bezierCurveTo(150.3, 311.7, 142.1, 306.0, 140.5, 297.4);
    ctx.bezierCurveTo(139.1, 290.0, 145.1, 285.7, 145.8, 285.3);
    ctx.bezierCurveTo(152.3, 280.8, 160.0, 279.7, 168.7, 281.8);
    ctx.lineTo(168.8, 281.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(174.3, 298.5);
    ctx.bezierCurveTo(174.5, 297.7, 175.4, 297.1, 176.3, 297.3);
    ctx.bezierCurveTo(177.2, 297.5, 177.8, 298.4, 177.6, 299.3);
    ctx.bezierCurveTo(177.3, 300.2, 176.4, 300.7, 175.5, 300.5);
    ctx.bezierCurveTo(174.6, 300.3, 174.1, 299.4, 174.3, 298.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(161.5, 298.0);
    ctx.bezierCurveTo(161.7, 297.1, 162.6, 296.6, 163.5, 296.8);
    ctx.bezierCurveTo(164.4, 297.0, 164.9, 297.9, 164.7, 298.8);
    ctx.bezierCurveTo(164.5, 299.7, 163.6, 300.2, 162.7, 300.0);
    ctx.bezierCurveTo(161.8, 299.8, 161.3, 298.9, 161.5, 298.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(149.7, 296.9);
    ctx.bezierCurveTo(149.9, 296.0, 150.8, 295.5, 151.7, 295.7);
    ctx.bezierCurveTo(152.6, 295.9, 153.1, 296.8, 152.9, 297.7);
    ctx.bezierCurveTo(152.7, 298.5, 151.8, 299.1, 150.9, 298.9);
    ctx.bezierCurveTo(150.0, 298.7, 149.5, 297.8, 149.7, 296.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(305.4, 197.6);
    ctx.bezierCurveTo(305.6, 197.6, 305.8, 197.6, 306.0, 197.6);
    ctx.bezierCurveTo(306.6, 197.5, 307.0, 197.0, 307.0, 196.5);
    ctx.lineTo(307.7, 184.5);
    ctx.bezierCurveTo(307.7, 184.3, 307.9, 184.0, 308.1, 183.9);
    ctx.bezierCurveTo(308.4, 183.8, 308.7, 183.6, 309.1, 183.4);
    ctx.bezierCurveTo(311.6, 182.3, 315.4, 180.7, 317.0, 174.1);
    ctx.bezierCurveTo(319.3, 164.2, 308.4, 157.2, 306.7, 156.4);
    ctx.bezierCurveTo(294.2, 151.3, 283.4, 151.6, 274.6, 157.5);
    ctx.bezierCurveTo(273.8, 158.0, 266.9, 162.9, 268.5, 171.3);
    ctx.bezierCurveTo(270.4, 180.7, 279.2, 186.9, 287.0, 188.0);
    ctx.bezierCurveTo(290.8, 188.6, 294.7, 188.2, 298.3, 186.8);
    ctx.lineTo(304.8, 197.0);
    ctx.bezierCurveTo(304.9, 197.3, 305.2, 197.5, 305.4, 197.6);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(298.4, 155.5);
    ctx.bezierCurveTo(301.0, 156.1, 303.6, 156.9, 306.0, 157.9);
    ctx.bezierCurveTo(306.1, 157.9, 317.6, 164.4, 315.4, 173.7);
    ctx.bezierCurveTo(314.0, 179.5, 310.8, 181.0, 308.4, 181.9);
    ctx.bezierCurveTo(308.0, 182.1, 307.7, 182.3, 307.4, 182.4);
    ctx.bezierCurveTo(306.6, 182.7, 306.1, 183.5, 306.0, 184.4);
    ctx.lineTo(305.4, 195.0);
    ctx.lineTo(299.6, 185.8);
    ctx.bezierCurveTo(299.2, 185.2, 298.5, 184.9, 297.8, 185.2);
    ctx.bezierCurveTo(294.4, 186.5, 290.8, 187.0, 287.2, 186.4);
    ctx.bezierCurveTo(279.9, 185.3, 271.8, 179.7, 270.1, 171.1);
    ctx.bezierCurveTo(268.7, 163.6, 274.7, 159.3, 275.4, 158.9);
    ctx.bezierCurveTo(282.0, 154.5, 289.6, 153.4, 298.4, 155.5);
    ctx.lineTo(298.4, 155.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(304.0, 172.2);
    ctx.bezierCurveTo(304.2, 171.3, 305.1, 170.8, 306.0, 171.0);
    ctx.bezierCurveTo(306.9, 171.2, 307.4, 172.1, 307.2, 173.0);
    ctx.bezierCurveTo(307.0, 173.9, 306.1, 174.4, 305.2, 174.2);
    ctx.bezierCurveTo(304.3, 174.0, 303.7, 173.1, 304.0, 172.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(291.1, 171.7);
    ctx.bezierCurveTo(291.3, 170.8, 292.2, 170.3, 293.2, 170.5);
    ctx.bezierCurveTo(294.1, 170.7, 294.6, 171.6, 294.4, 172.5);
    ctx.bezierCurveTo(294.2, 173.4, 293.3, 173.9, 292.4, 173.7);
    ctx.bezierCurveTo(291.5, 173.5, 290.9, 172.6, 291.1, 171.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(279.3, 170.6);
    ctx.bezierCurveTo(279.5, 169.7, 280.4, 169.2, 281.3, 169.4);
    ctx.bezierCurveTo(282.2, 169.6, 282.8, 170.5, 282.6, 171.4);
    ctx.bezierCurveTo(282.4, 172.2, 281.5, 172.8, 280.6, 172.6);
    ctx.bezierCurveTo(279.7, 172.4, 279.1, 171.5, 279.3, 170.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(50.0, 57.1);
    ctx.bezierCurveTo(50.2, 57.2, 50.4, 57.2, 50.6, 57.1);
    ctx.bezierCurveTo(51.2, 57.0, 51.6, 56.6, 51.6, 56.0);
    ctx.lineTo(52.3, 44.1);
    ctx.bezierCurveTo(52.3, 43.8, 52.5, 43.6, 52.7, 43.4);
    ctx.bezierCurveTo(53.0, 43.3, 53.3, 43.2, 53.7, 43.0);
    ctx.bezierCurveTo(56.2, 41.9, 60.0, 40.3, 61.5, 33.6);
    ctx.bezierCurveTo(63.9, 23.8, 53.0, 16.7, 51.3, 16.0);
    ctx.bezierCurveTo(38.8, 10.8, 28.0, 11.1, 19.2, 17.0);
    ctx.bezierCurveTo(18.4, 17.5, 11.5, 22.4, 13.1, 30.8);
    ctx.bezierCurveTo(14.9, 40.2, 23.8, 46.4, 31.5, 47.6);
    ctx.bezierCurveTo(35.3, 48.1, 39.2, 47.7, 42.9, 46.3);
    ctx.lineTo(49.3, 56.5);
    ctx.bezierCurveTo(49.5, 56.8, 49.7, 57.0, 50.0, 57.1);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(43.0, 15.0);
    ctx.bezierCurveTo(45.6, 15.6, 48.1, 16.5, 50.6, 17.5);
    ctx.bezierCurveTo(50.7, 17.5, 62.2, 24.0, 60.0, 33.2);
    ctx.bezierCurveTo(58.6, 39.1, 55.4, 40.5, 53.0, 41.5);
    ctx.bezierCurveTo(52.6, 41.6, 52.3, 41.8, 52.0, 41.9);
    ctx.bezierCurveTo(51.2, 42.3, 50.7, 43.1, 50.6, 43.9);
    ctx.lineTo(50.0, 54.6);
    ctx.lineTo(44.2, 45.4);
    ctx.bezierCurveTo(43.8, 44.8, 43.1, 44.5, 42.4, 44.8);
    ctx.bezierCurveTo(39.0, 46.1, 35.4, 46.5, 31.8, 46.0);
    ctx.bezierCurveTo(24.6, 44.9, 16.4, 39.3, 14.8, 30.7);
    ctx.bezierCurveTo(13.3, 23.2, 19.4, 18.9, 20.1, 18.5);
    ctx.bezierCurveTo(26.6, 14.1, 34.2, 12.9, 43.0, 15.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(48.6, 31.8);
    ctx.bezierCurveTo(48.8, 30.9, 49.7, 30.4, 50.6, 30.6);
    ctx.bezierCurveTo(51.5, 30.8, 52.0, 31.7, 51.8, 32.6);
    ctx.bezierCurveTo(51.6, 33.5, 50.7, 34.0, 49.8, 33.8);
    ctx.bezierCurveTo(48.9, 33.6, 48.3, 32.7, 48.6, 31.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(35.7, 31.3);
    ctx.bezierCurveTo(36.0, 30.4, 36.9, 29.9, 37.8, 30.1);
    ctx.bezierCurveTo(38.7, 30.3, 39.2, 31.2, 39.0, 32.1);
    ctx.bezierCurveTo(38.8, 32.9, 37.9, 33.5, 37.0, 33.3);
    ctx.bezierCurveTo(36.1, 33.0, 35.5, 32.2, 35.7, 31.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(23.9, 30.2);
    ctx.bezierCurveTo(24.1, 29.3, 25.0, 28.7, 25.9, 29.0);
    ctx.bezierCurveTo(26.9, 29.2, 27.4, 30.1, 27.2, 30.9);
    ctx.bezierCurveTo(27.0, 31.8, 26.1, 32.4, 25.2, 32.1);
    ctx.bezierCurveTo(24.3, 31.9, 23.7, 31.0, 23.9, 30.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(183.1, 144.4);
    ctx.bezierCurveTo(183.2, 144.5, 183.3, 144.5, 183.5, 144.4);
    ctx.bezierCurveTo(183.9, 144.4, 184.2, 144.0, 184.2, 143.6);
    ctx.lineTo(184.7, 135.1);
    ctx.bezierCurveTo(184.7, 134.9, 184.8, 134.7, 185.0, 134.6);
    ctx.bezierCurveTo(185.2, 134.5, 185.4, 134.4, 185.7, 134.3);
    ctx.bezierCurveTo(187.5, 133.5, 190.2, 132.3, 191.3, 127.5);
    ctx.bezierCurveTo(193.0, 120.5, 185.1, 115.4, 183.9, 114.9);
    ctx.bezierCurveTo(174.9, 111.1, 167.2, 111.4, 160.9, 115.6);
    ctx.bezierCurveTo(160.3, 116.0, 155.3, 119.5, 156.5, 125.6);
    ctx.bezierCurveTo(157.8, 132.3, 164.2, 136.7, 169.8, 137.6);
    ctx.bezierCurveTo(172.5, 138.0, 175.3, 137.7, 177.9, 136.7);
    ctx.lineTo(182.5, 144.0);
    ctx.bezierCurveTo(182.6, 144.2, 182.8, 144.4, 183.1, 144.4);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(178.0, 114.2);
    ctx.bezierCurveTo(179.9, 114.7, 181.7, 115.3, 183.5, 116.0);
    ctx.bezierCurveTo(183.5, 116.0, 191.8, 120.6, 190.2, 127.3);
    ctx.bezierCurveTo(189.2, 131.5, 186.9, 132.5, 185.2, 133.2);
    ctx.bezierCurveTo(184.9, 133.3, 184.7, 133.5, 184.5, 133.5);
    ctx.bezierCurveTo(183.9, 133.8, 183.5, 134.4, 183.5, 135.0);
    ctx.lineTo(183.0, 142.6);
    ctx.lineTo(178.9, 136.0);
    ctx.bezierCurveTo(178.6, 135.6, 178.1, 135.4, 177.6, 135.6);
    ctx.bezierCurveTo(175.2, 136.5, 172.5, 136.9, 169.9, 136.5);
    ctx.bezierCurveTo(164.7, 135.7, 158.9, 131.6, 157.7, 125.5);
    ctx.bezierCurveTo(156.7, 120.2, 161.0, 117.1, 161.5, 116.8);
    ctx.bezierCurveTo(166.2, 113.5, 171.7, 112.7, 178.0, 114.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(182.0, 126.2);
    ctx.bezierCurveTo(182.1, 125.6, 182.8, 125.2, 183.4, 125.4);
    ctx.bezierCurveTo(184.1, 125.5, 184.5, 126.2, 184.3, 126.8);
    ctx.bezierCurveTo(184.2, 127.4, 183.5, 127.8, 182.9, 127.7);
    ctx.bezierCurveTo(182.2, 127.5, 181.8, 126.9, 182.0, 126.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(172.8, 125.8);
    ctx.bezierCurveTo(172.9, 125.2, 173.6, 124.8, 174.2, 125.0);
    ctx.bezierCurveTo(174.9, 125.1, 175.3, 125.8, 175.1, 126.4);
    ctx.bezierCurveTo(175.0, 127.0, 174.3, 127.4, 173.7, 127.3);
    ctx.bezierCurveTo(173.0, 127.1, 172.6, 126.5, 172.8, 125.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(164.3, 125.0);
    ctx.bezierCurveTo(164.4, 124.4, 165.1, 124.0, 165.7, 124.2);
    ctx.bezierCurveTo(166.4, 124.3, 166.8, 125.0, 166.6, 125.6);
    ctx.bezierCurveTo(166.5, 126.2, 165.8, 126.6, 165.2, 126.5);
    ctx.bezierCurveTo(164.5, 126.3, 164.1, 125.7, 164.3, 125.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(153.9, 109.8);
    ctx.bezierCurveTo(154.1, 109.8, 154.2, 109.8, 154.4, 109.8);
    ctx.bezierCurveTo(154.7, 109.7, 155.0, 109.4, 155.0, 109.0);
    ctx.lineTo(155.5, 100.4);
    ctx.bezierCurveTo(155.5, 100.2, 155.7, 100.1, 155.8, 100.0);
    ctx.bezierCurveTo(156.0, 99.9, 156.3, 99.8, 156.5, 99.6);
    ctx.bezierCurveTo(158.3, 98.9, 161.0, 97.6, 162.2, 92.9);
    ctx.bezierCurveTo(163.8, 85.9, 156.0, 80.8, 154.8, 80.2);
    ctx.bezierCurveTo(145.8, 76.5, 138.1, 76.7, 131.8, 81.0);
    ctx.bezierCurveTo(131.2, 81.3, 126.3, 84.9, 127.4, 90.9);
    ctx.bezierCurveTo(128.7, 97.7, 135.1, 102.1, 140.7, 102.9);
    ctx.bezierCurveTo(143.4, 103.3, 146.2, 103.0, 148.8, 102.0);
    ctx.lineTo(153.5, 109.4);
    ctx.bezierCurveTo(153.6, 109.6, 153.7, 109.7, 153.9, 109.8);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(148.9, 79.5);
    ctx.bezierCurveTo(150.7, 80.0, 152.5, 80.6, 154.3, 81.3);
    ctx.bezierCurveTo(154.4, 81.3, 162.6, 86.0, 161.0, 92.6);
    ctx.bezierCurveTo(160.0, 96.8, 157.8, 97.9, 156.0, 98.5);
    ctx.bezierCurveTo(155.8, 98.7, 155.6, 98.8, 155.3, 98.9);
    ctx.bezierCurveTo(154.8, 99.1, 154.4, 99.7, 154.3, 100.3);
    ctx.lineTo(153.9, 108.0);
    ctx.lineTo(149.7, 101.3);
    ctx.bezierCurveTo(149.5, 100.9, 148.9, 100.7, 148.4, 100.9);
    ctx.bezierCurveTo(146.0, 101.9, 143.4, 102.2, 140.8, 101.8);
    ctx.bezierCurveTo(135.6, 101.0, 129.7, 96.9, 128.5, 90.8);
    ctx.bezierCurveTo(127.5, 85.4, 131.9, 82.3, 132.4, 82.0);
    ctx.bezierCurveTo(137.1, 78.8, 142.6, 78.0, 148.9, 79.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(152.9, 91.6);
    ctx.bezierCurveTo(153.0, 91.0, 153.7, 90.6, 154.3, 90.7);
    ctx.bezierCurveTo(155.0, 90.9, 155.4, 91.5, 155.2, 92.2);
    ctx.bezierCurveTo(155.1, 92.8, 154.4, 93.2, 153.8, 93.0);
    ctx.bezierCurveTo(153.1, 92.9, 152.7, 92.2, 152.9, 91.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(143.6, 91.2);
    ctx.bezierCurveTo(143.8, 90.6, 144.4, 90.2, 145.1, 90.3);
    ctx.bezierCurveTo(145.7, 90.5, 146.1, 91.1, 146.0, 91.8);
    ctx.bezierCurveTo(145.8, 92.4, 145.2, 92.8, 144.5, 92.6);
    ctx.bezierCurveTo(143.9, 92.5, 143.5, 91.9, 143.6, 91.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(135.2, 90.4);
    ctx.bezierCurveTo(135.3, 89.8, 136.0, 89.4, 136.6, 89.5);
    ctx.bezierCurveTo(137.3, 89.7, 137.7, 90.3, 137.5, 91.0);
    ctx.bezierCurveTo(137.4, 91.6, 136.7, 92.0, 136.1, 91.8);
    ctx.bezierCurveTo(135.4, 91.7, 135.0, 91.0, 135.2, 90.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(269.1, 146.4);
    ctx.bezierCurveTo(269.3, 146.4, 269.4, 146.4, 269.6, 146.4);
    ctx.bezierCurveTo(269.9, 146.3, 270.2, 146.0, 270.2, 145.6);
    ctx.lineTo(270.7, 137.0);
    ctx.bezierCurveTo(270.7, 136.8, 270.9, 136.6, 271.0, 136.5);
    ctx.bezierCurveTo(271.2, 136.5, 271.4, 136.3, 271.7, 136.2);
    ctx.bezierCurveTo(273.5, 135.4, 276.2, 134.2, 277.4, 129.5);
    ctx.bezierCurveTo(279.0, 122.4, 271.2, 117.3, 270.0, 116.8);
    ctx.bezierCurveTo(261.0, 113.1, 253.3, 113.3, 246.9, 117.6);
    ctx.bezierCurveTo(246.3, 117.9, 241.4, 121.5, 242.6, 127.6);
    ctx.bezierCurveTo(243.9, 134.3, 250.2, 138.7, 255.8, 139.6);
    ctx.bezierCurveTo(258.6, 140.0, 261.4, 139.6, 264.0, 138.6);
    ctx.lineTo(268.6, 146.0);
    ctx.bezierCurveTo(268.7, 146.2, 268.9, 146.3, 269.1, 146.4);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(264.1, 116.1);
    ctx.bezierCurveTo(265.9, 116.6, 267.7, 117.2, 269.5, 117.9);
    ctx.bezierCurveTo(269.6, 117.9, 277.8, 122.5, 276.2, 129.2);
    ctx.bezierCurveTo(275.2, 133.4, 273.0, 134.4, 271.2, 135.1);
    ctx.bezierCurveTo(271.0, 135.2, 270.8, 135.4, 270.6, 135.4);
    ctx.bezierCurveTo(270.0, 135.7, 269.6, 136.3, 269.6, 136.9);
    ctx.lineTo(269.1, 144.6);
    ctx.lineTo(264.9, 137.9);
    ctx.bezierCurveTo(264.7, 137.5, 264.1, 137.3, 263.6, 137.5);
    ctx.bezierCurveTo(261.2, 138.5, 258.6, 138.8, 256.0, 138.4);
    ctx.bezierCurveTo(250.8, 137.6, 245.0, 133.5, 243.8, 127.4);
    ctx.bezierCurveTo(242.8, 122.1, 247.1, 119.0, 247.6, 118.7);
    ctx.bezierCurveTo(252.3, 115.4, 257.8, 114.6, 264.1, 116.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(268.0, 128.2);
    ctx.bezierCurveTo(268.2, 127.5, 268.8, 127.1, 269.5, 127.3);
    ctx.bezierCurveTo(270.1, 127.4, 270.6, 128.1, 270.4, 128.7);
    ctx.bezierCurveTo(270.3, 129.4, 269.6, 129.7, 269.0, 129.6);
    ctx.bezierCurveTo(268.3, 129.4, 267.9, 128.8, 268.0, 128.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(258.8, 127.8);
    ctx.bezierCurveTo(259.0, 127.2, 259.6, 126.8, 260.3, 126.9);
    ctx.bezierCurveTo(260.9, 127.1, 261.3, 127.7, 261.2, 128.4);
    ctx.bezierCurveTo(261.0, 129.0, 260.4, 129.4, 259.7, 129.2);
    ctx.bezierCurveTo(259.1, 129.1, 258.7, 128.4, 258.8, 127.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(250.4, 127.0);
    ctx.bezierCurveTo(250.5, 126.3, 251.2, 126.0, 251.8, 126.1);
    ctx.bezierCurveTo(252.5, 126.3, 252.9, 126.9, 252.7, 127.5);
    ctx.bezierCurveTo(252.6, 128.2, 251.9, 128.6, 251.3, 128.4);
    ctx.bezierCurveTo(250.6, 128.3, 250.2, 127.6, 250.4, 127.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(270.8, 111.9);
    ctx.bezierCurveTo(270.9, 111.9, 271.1, 111.9, 271.2, 111.9);
    ctx.bezierCurveTo(271.5, 111.8, 271.8, 111.5, 271.8, 111.2);
    ctx.lineTo(272.3, 103.2);
    ctx.bezierCurveTo(272.3, 103.0, 272.5, 102.8, 272.6, 102.7);
    ctx.bezierCurveTo(272.8, 102.6, 273.0, 102.5, 273.2, 102.4);
    ctx.bezierCurveTo(274.8, 101.7, 277.2, 100.5, 278.3, 96.1);
    ctx.bezierCurveTo(279.9, 89.5, 272.9, 84.9, 271.9, 84.4);
    ctx.bezierCurveTo(263.9, 81.0, 257.0, 81.3, 251.3, 85.3);
    ctx.bezierCurveTo(250.8, 85.6, 246.4, 89.0, 247.3, 94.6);
    ctx.bezierCurveTo(248.4, 100.8, 254.1, 104.9, 259.0, 105.6);
    ctx.bezierCurveTo(261.5, 105.9, 264.0, 105.6, 266.3, 104.7);
    ctx.lineTo(270.3, 111.5);
    ctx.bezierCurveTo(270.4, 111.7, 270.6, 111.8, 270.8, 111.9);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(266.6, 83.8);
    ctx.bezierCurveTo(268.2, 84.2, 269.9, 84.8, 271.4, 85.4);
    ctx.bezierCurveTo(271.5, 85.4, 278.8, 89.7, 277.3, 95.9);
    ctx.bezierCurveTo(276.4, 99.8, 274.3, 100.8, 272.8, 101.4);
    ctx.bezierCurveTo(272.6, 101.5, 272.4, 101.7, 272.2, 101.7);
    ctx.bezierCurveTo(271.7, 102.0, 271.3, 102.5, 271.3, 103.1);
    ctx.lineTo(270.8, 110.2);
    ctx.lineTo(267.2, 104.1);
    ctx.bezierCurveTo(266.9, 103.7, 266.5, 103.5, 266.0, 103.7);
    ctx.bezierCurveTo(263.9, 104.6, 261.5, 104.9, 259.2, 104.6);
    ctx.bezierCurveTo(254.6, 103.9, 249.4, 100.2, 248.4, 94.5);
    ctx.bezierCurveTo(247.9, 91.3, 249.3, 88.2, 251.9, 86.3);
    ctx.bezierCurveTo(256.1, 83.3, 261.0, 82.5, 266.6, 83.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(270.0, 95.0);
    ctx.bezierCurveTo(270.2, 94.4, 270.8, 94.0, 271.3, 94.2);
    ctx.bezierCurveTo(271.9, 94.3, 272.3, 94.9, 272.1, 95.5);
    ctx.bezierCurveTo(272.0, 96.1, 271.4, 96.5, 270.8, 96.3);
    ctx.bezierCurveTo(270.2, 96.2, 269.9, 95.6, 270.0, 95.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(261.8, 94.7);
    ctx.bezierCurveTo(262.0, 94.1, 262.6, 93.8, 263.1, 93.9);
    ctx.bezierCurveTo(263.7, 94.0, 264.1, 94.6, 263.9, 95.2);
    ctx.bezierCurveTo(263.8, 95.8, 263.2, 96.2, 262.6, 96.1);
    ctx.bezierCurveTo(262.0, 95.9, 261.7, 95.3, 261.8, 94.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(254.3, 94.1);
    ctx.bezierCurveTo(254.4, 93.5, 255.0, 93.1, 255.6, 93.2);
    ctx.bezierCurveTo(256.2, 93.4, 256.5, 94.0, 256.4, 94.6);
    ctx.bezierCurveTo(256.2, 95.2, 255.7, 95.5, 255.1, 95.4);
    ctx.bezierCurveTo(254.5, 95.2, 254.2, 94.7, 254.3, 94.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(330.7, 68.7);
    ctx.bezierCurveTo(330.8, 68.8, 331.0, 68.8, 331.1, 68.7);
    ctx.bezierCurveTo(331.5, 68.6, 331.8, 68.3, 331.8, 67.9);
    ctx.lineTo(332.4, 58.9);
    ctx.bezierCurveTo(332.4, 58.7, 332.6, 58.5, 332.7, 58.4);
    ctx.bezierCurveTo(332.9, 58.3, 333.1, 58.2, 333.4, 58.0);
    ctx.bezierCurveTo(335.2, 57.2, 337.8, 55.9, 339.0, 50.9);
    ctx.bezierCurveTo(340.7, 43.4, 333.3, 38.3, 332.1, 37.7);
    ctx.bezierCurveTo(323.6, 34.0, 316.1, 34.4, 310.0, 39.0);
    ctx.bezierCurveTo(309.4, 39.4, 304.6, 43.2, 305.6, 49.5);
    ctx.bezierCurveTo(306.7, 55.9, 311.7, 60.8, 318.0, 61.8);
    ctx.bezierCurveTo(320.7, 62.2, 323.4, 61.8, 325.9, 60.7);
    ctx.lineTo(330.1, 68.3);
    ctx.bezierCurveTo(330.3, 68.5, 330.4, 68.7, 330.7, 68.7);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(326.5, 37.1);
    ctx.bezierCurveTo(328.3, 37.6, 330.0, 38.2, 331.7, 38.9);
    ctx.bezierCurveTo(331.7, 38.9, 339.6, 43.6, 337.9, 50.6);
    ctx.bezierCurveTo(336.8, 55.0, 334.6, 56.1, 333.0, 56.9);
    ctx.bezierCurveTo(332.7, 57.0, 332.5, 57.2, 332.3, 57.2);
    ctx.bezierCurveTo(331.7, 57.6, 331.3, 58.1, 331.3, 58.8);
    ctx.lineTo(330.7, 66.8);
    ctx.lineTo(326.8, 59.9);
    ctx.bezierCurveTo(326.6, 59.5, 326.0, 59.3, 325.6, 59.5);
    ctx.bezierCurveTo(323.3, 60.6, 320.7, 61.0, 318.2, 60.6);
    ctx.bezierCurveTo(312.4, 59.7, 307.8, 55.2, 306.7, 49.3);
    ctx.bezierCurveTo(306.2, 45.8, 307.7, 42.3, 310.5, 40.1);
    ctx.bezierCurveTo(315.1, 36.7, 320.5, 35.7, 326.5, 37.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(330.0, 49.7);
    ctx.bezierCurveTo(330.2, 49.0, 330.8, 48.6, 331.5, 48.7);
    ctx.bezierCurveTo(332.1, 48.9, 332.4, 49.5, 332.3, 50.2);
    ctx.bezierCurveTo(332.1, 50.9, 331.5, 51.3, 330.9, 51.1);
    ctx.bezierCurveTo(330.3, 51.0, 329.9, 50.3, 330.0, 49.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(321.2, 49.5);
    ctx.bezierCurveTo(321.4, 48.8, 322.0, 48.4, 322.6, 48.6);
    ctx.bezierCurveTo(323.2, 48.7, 323.6, 49.4, 323.4, 50.0);
    ctx.bezierCurveTo(323.3, 50.7, 322.7, 51.1, 322.0, 51.0);
    ctx.bezierCurveTo(321.4, 50.8, 321.0, 50.2, 321.2, 49.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(313.1, 48.8);
    ctx.bezierCurveTo(313.2, 48.2, 313.9, 47.7, 314.5, 47.9);
    ctx.bezierCurveTo(315.1, 48.0, 315.5, 48.7, 315.3, 49.4);
    ctx.bezierCurveTo(315.1, 50.0, 314.5, 50.4, 313.9, 50.3);
    ctx.bezierCurveTo(313.3, 50.2, 312.9, 49.5, 313.1, 48.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(358.7, 46.8);
    ctx.bezierCurveTo(358.8, 46.9, 359.0, 46.9, 359.1, 46.8);
    ctx.bezierCurveTo(359.4, 46.7, 359.7, 46.4, 359.7, 46.1);
    ctx.lineTo(360.3, 37.9);
    ctx.bezierCurveTo(360.3, 37.7, 360.4, 37.6, 360.6, 37.5);
    ctx.bezierCurveTo(360.7, 37.4, 360.9, 37.3, 361.2, 37.1);
    ctx.bezierCurveTo(362.7, 36.4, 365.1, 35.1, 366.2, 30.6);
    ctx.bezierCurveTo(367.8, 23.9, 361.1, 19.2, 360.0, 18.7);
    ctx.bezierCurveTo(352.3, 15.4, 345.6, 15.7, 340.0, 19.9);
    ctx.bezierCurveTo(337.1, 22.2, 335.5, 25.8, 336.0, 29.5);
    ctx.bezierCurveTo(337.0, 35.2, 341.5, 39.7, 347.3, 40.6);
    ctx.bezierCurveTo(349.7, 40.9, 352.1, 40.6, 354.4, 39.6);
    ctx.lineTo(358.2, 46.5);
    ctx.bezierCurveTo(358.3, 46.7, 358.5, 46.8, 358.7, 46.8);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(355.0, 18.2);
    ctx.bezierCurveTo(356.6, 18.6, 358.2, 19.1, 359.7, 19.8);
    ctx.bezierCurveTo(359.7, 19.8, 366.8, 24.0, 365.3, 30.4);
    ctx.bezierCurveTo(364.3, 34.4, 362.3, 35.4, 360.8, 36.1);
    ctx.bezierCurveTo(360.6, 36.2, 360.4, 36.3, 360.2, 36.4);
    ctx.bezierCurveTo(359.7, 36.7, 359.4, 37.2, 359.3, 37.8);
    ctx.lineTo(358.8, 45.1);
    ctx.lineTo(355.3, 38.9);
    ctx.bezierCurveTo(355.1, 38.5, 354.6, 38.3, 354.2, 38.5);
    ctx.bezierCurveTo(352.1, 39.5, 349.8, 39.8, 347.5, 39.5);
    ctx.bezierCurveTo(342.2, 38.7, 338.1, 34.5, 337.1, 29.3);
    ctx.bezierCurveTo(336.7, 26.0, 338.1, 22.8, 340.6, 20.9);
    ctx.bezierCurveTo(344.7, 17.8, 349.5, 16.9, 355.0, 18.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(358.2, 29.6);
    ctx.bezierCurveTo(358.3, 29.0, 358.9, 28.6, 359.4, 28.7);
    ctx.bezierCurveTo(360.0, 28.8, 360.3, 29.4, 360.2, 30.0);
    ctx.bezierCurveTo(360.0, 30.6, 359.5, 31.0, 358.9, 30.9);
    ctx.bezierCurveTo(358.3, 30.8, 358.0, 30.2, 358.2, 29.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(350.2, 29.4);
    ctx.bezierCurveTo(350.3, 28.8, 350.9, 28.4, 351.4, 28.5);
    ctx.bezierCurveTo(352.0, 28.7, 352.3, 29.3, 352.2, 29.9);
    ctx.bezierCurveTo(352.0, 30.5, 351.5, 30.9, 350.9, 30.7);
    ctx.bezierCurveTo(350.3, 30.6, 350.0, 30.0, 350.2, 29.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(342.8, 28.8);
    ctx.bezierCurveTo(343.0, 28.2, 343.5, 27.8, 344.1, 27.9);
    ctx.bezierCurveTo(344.6, 28.1, 345.0, 28.7, 344.8, 29.3);
    ctx.bezierCurveTo(344.7, 29.9, 344.1, 30.3, 343.6, 30.1);
    ctx.bezierCurveTo(343.0, 30.0, 342.7, 29.4, 342.8, 28.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(273.4, 48.5);
    ctx.bezierCurveTo(273.6, 48.5, 273.7, 48.5, 273.8, 48.5);
    ctx.bezierCurveTo(274.2, 48.4, 274.4, 48.1, 274.4, 47.7);
    ctx.lineTo(275.0, 39.6);
    ctx.bezierCurveTo(275.1, 39.4, 275.2, 39.2, 275.3, 39.1);
    ctx.bezierCurveTo(275.5, 39.0, 275.7, 38.9, 275.9, 38.8);
    ctx.bezierCurveTo(277.5, 38.0, 279.9, 36.8, 280.9, 32.3);
    ctx.bezierCurveTo(282.5, 25.5, 275.8, 20.9, 274.8, 20.4);
    ctx.bezierCurveTo(267.1, 17.0, 260.3, 17.4, 254.8, 21.6);
    ctx.bezierCurveTo(251.8, 23.8, 250.3, 27.5, 250.8, 31.1);
    ctx.bezierCurveTo(251.8, 36.8, 256.3, 41.3, 262.0, 42.2);
    ctx.bezierCurveTo(264.4, 42.5, 266.9, 42.2, 269.1, 41.2);
    ctx.lineTo(273.0, 48.1);
    ctx.bezierCurveTo(273.1, 48.3, 273.2, 48.4, 273.4, 48.5);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(269.7, 19.8);
    ctx.bezierCurveTo(271.3, 20.2, 272.9, 20.8, 274.4, 21.4);
    ctx.bezierCurveTo(274.4, 21.4, 281.5, 25.7, 280.0, 32.0);
    ctx.bezierCurveTo(279.0, 36.0, 277.0, 37.0, 275.5, 37.7);
    ctx.bezierCurveTo(275.3, 37.9, 275.1, 38.0, 274.9, 38.1);
    ctx.bezierCurveTo(274.4, 38.4, 274.1, 38.9, 274.0, 39.5);
    ctx.lineTo(273.5, 46.8);
    ctx.lineTo(270.0, 40.5);
    ctx.bezierCurveTo(269.8, 40.2, 269.3, 40.0, 268.9, 40.2);
    ctx.bezierCurveTo(266.8, 41.2, 264.5, 41.5, 262.2, 41.2);
    ctx.bezierCurveTo(256.9, 40.4, 252.8, 36.2, 251.8, 31.0);
    ctx.bezierCurveTo(251.4, 27.7, 252.7, 24.5, 255.3, 22.6);
    ctx.bezierCurveTo(259.5, 19.4, 264.3, 18.5, 269.7, 19.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(272.9, 31.2);
    ctx.bezierCurveTo(273.0, 30.6, 273.6, 30.2, 274.2, 30.3);
    ctx.bezierCurveTo(274.7, 30.5, 275.1, 31.1, 274.9, 31.7);
    ctx.bezierCurveTo(274.8, 32.3, 274.2, 32.7, 273.6, 32.5);
    ctx.bezierCurveTo(273.1, 32.4, 272.8, 31.8, 272.9, 31.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(264.9, 31.1);
    ctx.bezierCurveTo(265.1, 30.4, 265.6, 30.1, 266.2, 30.2);
    ctx.bezierCurveTo(266.7, 30.3, 267.1, 30.9, 266.9, 31.5);
    ctx.bezierCurveTo(266.8, 32.1, 266.2, 32.5, 265.7, 32.4);
    ctx.bezierCurveTo(265.1, 32.3, 264.8, 31.7, 264.9, 31.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(257.6, 30.5);
    ctx.bezierCurveTo(257.7, 29.8, 258.3, 29.5, 258.8, 29.6);
    ctx.bezierCurveTo(259.4, 29.7, 259.7, 30.3, 259.6, 30.9);
    ctx.bezierCurveTo(259.5, 31.5, 258.9, 31.9, 258.3, 31.8);
    ctx.bezierCurveTo(257.8, 31.7, 257.4, 31.1, 257.6, 30.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(73.8, 187.9);
    ctx.bezierCurveTo(73.9, 187.9, 74.1, 187.9, 74.2, 187.9);
    ctx.bezierCurveTo(74.5, 187.8, 74.8, 187.5, 74.8, 187.1);
    ctx.lineTo(75.4, 179.0);
    ctx.bezierCurveTo(75.4, 178.8, 75.5, 178.6, 75.7, 178.5);
    ctx.bezierCurveTo(75.8, 178.4, 76.0, 178.3, 76.3, 178.2);
    ctx.bezierCurveTo(77.9, 177.4, 80.2, 176.2, 81.3, 171.7);
    ctx.bezierCurveTo(82.9, 164.9, 76.2, 160.3, 75.1, 159.8);
    ctx.bezierCurveTo(67.4, 156.4, 60.7, 156.8, 55.1, 161.0);
    ctx.bezierCurveTo(52.2, 163.2, 50.7, 166.8, 51.1, 170.5);
    ctx.bezierCurveTo(52.1, 176.3, 56.6, 180.7, 62.4, 181.7);
    ctx.bezierCurveTo(64.8, 182.0, 67.3, 181.6, 69.5, 180.7);
    ctx.lineTo(73.3, 187.5);
    ctx.bezierCurveTo(73.5, 187.7, 73.6, 187.8, 73.8, 187.9);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(70.1, 159.2);
    ctx.bezierCurveTo(71.7, 159.6, 73.2, 160.1, 74.8, 160.8);
    ctx.bezierCurveTo(74.8, 160.8, 81.9, 165.0, 80.3, 171.4);
    ctx.bezierCurveTo(79.4, 175.4, 77.3, 176.4, 75.9, 177.1);
    ctx.bezierCurveTo(75.7, 177.2, 75.4, 177.4, 75.3, 177.4);
    ctx.bezierCurveTo(74.8, 177.7, 74.4, 178.3, 74.4, 178.9);
    ctx.lineTo(73.8, 186.2);
    ctx.lineTo(70.3, 180.0);
    ctx.bezierCurveTo(70.2, 179.6, 69.7, 179.4, 69.3, 179.6);
    ctx.bezierCurveTo(67.2, 180.6, 64.9, 180.9, 62.6, 180.6);
    ctx.bezierCurveTo(57.3, 179.8, 53.1, 175.6, 52.2, 170.4);
    ctx.bezierCurveTo(51.8, 167.1, 53.1, 163.9, 55.7, 162.0);
    ctx.bezierCurveTo(59.8, 158.8, 64.6, 157.9, 70.1, 159.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(73.3, 170.6);
    ctx.bezierCurveTo(73.4, 170.0, 74.0, 169.6, 74.6, 169.7);
    ctx.bezierCurveTo(75.1, 169.9, 75.4, 170.5, 75.3, 171.1);
    ctx.bezierCurveTo(75.2, 171.7, 74.6, 172.1, 74.0, 171.9);
    ctx.bezierCurveTo(73.5, 171.8, 73.1, 171.2, 73.3, 170.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(65.3, 170.4);
    ctx.bezierCurveTo(65.4, 169.8, 66.0, 169.4, 66.6, 169.6);
    ctx.bezierCurveTo(67.1, 169.7, 67.5, 170.3, 67.3, 170.9);
    ctx.bezierCurveTo(67.2, 171.5, 66.6, 171.9, 66.0, 171.8);
    ctx.bezierCurveTo(65.5, 171.6, 65.1, 171.0, 65.3, 170.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(57.9, 169.9);
    ctx.bezierCurveTo(58.1, 169.2, 58.6, 168.9, 59.2, 169.0);
    ctx.bezierCurveTo(59.8, 169.1, 60.1, 169.7, 60.0, 170.3);
    ctx.bezierCurveTo(59.8, 170.9, 59.2, 171.3, 58.7, 171.2);
    ctx.bezierCurveTo(58.1, 171.1, 57.8, 170.5, 57.9, 169.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(13.8, 196.3);
    ctx.bezierCurveTo(13.6, 196.3, 13.4, 196.3, 13.3, 196.3);
    ctx.bezierCurveTo(12.9, 196.2, 12.5, 195.9, 12.5, 195.5);
    ctx.lineTo(10.8, 186.7);
    ctx.bezierCurveTo(10.8, 186.5, 10.6, 186.3, 10.4, 186.2);
    ctx.bezierCurveTo(10.2, 186.2, 10.0, 186.1, 9.7, 186.0);
    ctx.bezierCurveTo(7.7, 185.4, 4.7, 184.6, 2.9, 179.8);
    ctx.bezierCurveTo(0.2, 172.7, 7.7, 166.3, 8.9, 165.6);
    ctx.bezierCurveTo(17.9, 160.5, 26.0, 159.6, 33.2, 163.1);
    ctx.bezierCurveTo(33.9, 163.4, 39.5, 166.4, 39.1, 172.9);
    ctx.bezierCurveTo(38.6, 180.1, 32.5, 185.6, 26.8, 187.2);
    ctx.bezierCurveTo(24.0, 188.0, 21.0, 188.1, 18.1, 187.4);
    ctx.lineTo(14.2, 195.7);
    ctx.bezierCurveTo(14.2, 195.9, 14.0, 196.1, 13.8, 196.3);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(15.1, 164.1);
    ctx.bezierCurveTo(13.2, 164.8, 11.3, 165.7, 9.6, 166.7);
    ctx.bezierCurveTo(9.5, 166.7, 1.4, 172.7, 4.0, 179.4);
    ctx.bezierCurveTo(5.6, 183.6, 8.1, 184.4, 10.0, 184.9);
    ctx.bezierCurveTo(10.3, 184.9, 10.5, 185.0, 10.8, 185.1);
    ctx.bezierCurveTo(11.4, 185.3, 11.9, 185.8, 12.0, 186.5);
    ctx.lineTo(13.5, 194.4);
    ctx.lineTo(17.0, 186.9);
    ctx.bezierCurveTo(17.2, 186.4, 17.8, 186.1, 18.3, 186.3);
    ctx.bezierCurveTo(21.0, 186.9, 23.8, 186.9, 26.4, 186.1);
    ctx.bezierCurveTo(31.8, 184.6, 37.4, 179.5, 37.8, 172.9);
    ctx.bezierCurveTo(38.2, 167.3, 33.2, 164.6, 32.7, 164.4);
    ctx.bezierCurveTo(27.4, 161.7, 21.5, 161.7, 15.1, 164.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(10.8, 176.5);
    ctx.bezierCurveTo(11.5, 176.2, 12.2, 176.6, 12.4, 177.2);
    ctx.bezierCurveTo(12.7, 177.8, 12.4, 178.6, 11.7, 178.8);
    ctx.bezierCurveTo(11.0, 179.1, 10.3, 178.7, 10.1, 178.1);
    ctx.bezierCurveTo(9.8, 177.5, 10.2, 176.7, 10.8, 176.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(20.4, 174.8);
    ctx.bezierCurveTo(21.1, 174.6, 21.8, 174.9, 22.1, 175.5);
    ctx.bezierCurveTo(22.3, 176.2, 22.0, 176.9, 21.3, 177.1);
    ctx.bezierCurveTo(20.6, 177.4, 19.9, 177.1, 19.7, 176.4);
    ctx.bezierCurveTo(19.4, 175.8, 19.8, 175.1, 20.4, 174.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(29.2, 172.8);
    ctx.bezierCurveTo(29.9, 172.5, 30.6, 172.9, 30.9, 173.5);
    ctx.bezierCurveTo(31.1, 174.1, 30.8, 174.9, 30.1, 175.1);
    ctx.bezierCurveTo(29.5, 175.4, 28.7, 175.0, 28.5, 174.4);
    ctx.bezierCurveTo(28.2, 173.8, 28.6, 173.0, 29.2, 172.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.restore();
    ctx.beginPath();
    ctx.moveTo(6.1, 214.0);
    ctx.bezierCurveTo(4.2, 213.0, 2.1, 212.4, 0.0, 212.1);
    ctx.lineTo(0.0, 213.4);
    ctx.bezierCurveTo(1.9, 213.7, 3.8, 214.3, 5.6, 215.2);
    ctx.bezierCurveTo(6.1, 215.4, 11.1, 218.1, 10.7, 223.7);
    ctx.bezierCurveTo(10.3, 230.1, 5.1, 235.0, 0.0, 236.7);
    ctx.lineTo(0.0, 238.0);
    ctx.bezierCurveTo(5.6, 236.2, 11.6, 230.8, 12.0, 223.7);
    ctx.bezierCurveTo(12.4, 217.3, 6.8, 214.3, 6.1, 214.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(2.1, 223.6);
    ctx.bezierCurveTo(2.8, 223.3, 3.5, 223.6, 3.8, 224.3);
    ctx.bezierCurveTo(4.0, 224.9, 3.7, 225.6, 3.0, 225.9);
    ctx.bezierCurveTo(2.3, 226.1, 1.6, 225.8, 1.4, 225.2);
    ctx.bezierCurveTo(1.1, 224.6, 1.5, 223.8, 2.1, 223.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(397.7, 217.5);
    ctx.bezierCurveTo(399.4, 216.5, 401.3, 215.6, 403.1, 214.9);
    ctx.bezierCurveTo(407.0, 213.3, 411.1, 212.8, 415.2, 213.4);
    ctx.lineTo(415.2, 212.1);
    ctx.bezierCurveTo(409.6, 211.2, 403.5, 212.7, 397.0, 216.4);
    ctx.bezierCurveTo(395.8, 217.2, 388.3, 223.5, 391.0, 230.6);
    ctx.bezierCurveTo(392.8, 235.4, 395.8, 236.3, 397.8, 236.8);
    ctx.bezierCurveTo(398.1, 236.9, 398.3, 237.0, 398.5, 237.1);
    ctx.bezierCurveTo(398.7, 237.1, 398.9, 237.3, 398.9, 237.5);
    ctx.lineTo(400.6, 246.4);
    ctx.bezierCurveTo(400.6, 246.8, 401.0, 247.1, 401.4, 247.1);
    ctx.bezierCurveTo(401.8, 247.2, 402.2, 246.9, 402.3, 246.5);
    ctx.lineTo(406.2, 238.3);
    ctx.bezierCurveTo(409.1, 238.9, 412.1, 238.8, 414.9, 238.1);
    ctx.lineTo(415.2, 238.0);
    ctx.lineTo(415.2, 236.7);
    ctx.bezierCurveTo(415.0, 236.8, 414.8, 236.9, 414.5, 236.9);
    ctx.bezierCurveTo(411.9, 237.7, 409.1, 237.7, 406.4, 237.1);
    ctx.bezierCurveTo(405.9, 236.9, 405.3, 237.2, 405.1, 237.7);
    ctx.lineTo(401.6, 245.2);
    ctx.lineTo(400.1, 237.3);
    ctx.bezierCurveTo(400.0, 236.7, 399.5, 236.1, 398.9, 235.9);
    ctx.bezierCurveTo(398.7, 235.9, 398.4, 235.8, 398.1, 235.7);
    ctx.bezierCurveTo(396.2, 235.2, 393.7, 234.5, 392.1, 230.3);
    ctx.bezierCurveTo(389.5, 223.5, 397.6, 217.5, 397.7, 217.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(398.9, 227.3);
    ctx.bezierCurveTo(399.6, 227.0, 400.3, 227.4, 400.5, 228.0);
    ctx.bezierCurveTo(400.8, 228.6, 400.4, 229.4, 399.8, 229.6);
    ctx.bezierCurveTo(399.1, 229.9, 398.4, 229.6, 398.2, 228.9);
    ctx.bezierCurveTo(397.9, 228.3, 398.2, 227.6, 398.9, 227.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(408.5, 225.6);
    ctx.bezierCurveTo(409.2, 225.4, 409.9, 225.7, 410.2, 226.3);
    ctx.bezierCurveTo(410.4, 227.0, 410.1, 227.7, 409.4, 227.9);
    ctx.bezierCurveTo(408.8, 228.2, 408.0, 227.9, 407.8, 227.2);
    ctx.bezierCurveTo(407.5, 226.6, 407.9, 225.9, 408.5, 225.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(232.2, 165.1);
    ctx.bezierCurveTo(231.9, 165.1, 231.6, 164.9, 231.4, 164.7);
    ctx.lineTo(225.3, 155.2);
    ctx.lineTo(232.2, 165.1);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(225.3, 155.1);
    ctx.bezierCurveTo(221.9, 156.4, 218.3, 156.8, 214.7, 156.3);
    ctx.bezierCurveTo(207.6, 155.2, 199.5, 149.7, 197.7, 141.2);
    ctx.bezierCurveTo(196.2, 133.6, 202.4, 129.3, 203.1, 128.8);
    ctx.bezierCurveTo(211.2, 123.5, 221.1, 123.2, 232.6, 127.9);
    ctx.bezierCurveTo(234.1, 128.5, 244.2, 135.1, 242.1, 143.8);
    ctx.bezierCurveTo(240.7, 149.8, 237.2, 151.2, 235.0, 152.2);
    ctx.lineTo(234.1, 152.6);
    ctx.bezierCurveTo(233.8, 152.8, 233.6, 153.1, 233.6, 153.4);
    ctx.lineTo(233.0, 164.3);
    ctx.bezierCurveTo(233.0, 164.7, 232.7, 165.0, 232.4, 165.1);
    ctx.lineTo(232.2, 165.1);
    ctx.lineTo(225.3, 155.1);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(225.3, 154.1);
    ctx.bezierCurveTo(225.7, 154.1, 226.0, 154.3, 226.2, 154.6);
    ctx.lineTo(226.2, 154.6);
    ctx.lineTo(232.1, 163.8);
    ctx.lineTo(232.7, 153.2);
    ctx.bezierCurveTo(232.7, 152.5, 233.2, 151.9, 233.8, 151.6);
    ctx.lineTo(234.7, 151.2);
    ctx.bezierCurveTo(236.9, 150.3, 239.9, 149.0, 241.2, 143.5);
    ctx.bezierCurveTo(243.1, 135.4, 233.7, 129.4, 232.3, 128.8);
    ctx.bezierCurveTo(221.1, 124.2, 211.5, 124.4, 203.7, 129.6);
    ctx.bezierCurveTo(203.0, 130.0, 197.3, 134.0, 198.7, 141.0);
    ctx.bezierCurveTo(200.3, 149.0, 208.1, 154.3, 214.8, 155.4);
    ctx.bezierCurveTo(218.2, 155.9, 221.7, 155.5, 224.9, 154.3);
    ctx.bezierCurveTo(225.0, 154.2, 225.1, 154.1, 225.3, 154.1);
    ctx.lineTo(225.3, 154.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(230.4, 142.1);
    ctx.bezierCurveTo(230.6, 141.3, 231.5, 140.8, 232.3, 141.1);
    ctx.bezierCurveTo(233.2, 141.3, 233.7, 142.1, 233.5, 142.9);
    ctx.bezierCurveTo(233.3, 143.7, 232.5, 144.2, 231.6, 144.0);
    ctx.bezierCurveTo(230.8, 143.8, 230.2, 142.9, 230.4, 142.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(218.5, 141.6);
    ctx.bezierCurveTo(218.7, 140.8, 219.6, 140.3, 220.4, 140.5);
    ctx.bezierCurveTo(221.3, 140.7, 221.8, 141.6, 221.6, 142.4);
    ctx.bezierCurveTo(221.4, 143.2, 220.6, 143.7, 219.7, 143.5);
    ctx.bezierCurveTo(218.9, 143.3, 218.3, 142.4, 218.5, 141.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(207.5, 140.6);
    ctx.bezierCurveTo(207.7, 139.8, 208.6, 139.3, 209.4, 139.5);
    ctx.bezierCurveTo(210.3, 139.7, 210.8, 140.5, 210.6, 141.3);
    ctx.bezierCurveTo(210.4, 142.1, 209.6, 142.6, 208.7, 142.4);
    ctx.bezierCurveTo(207.9, 142.2, 207.3, 141.4, 207.5, 140.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(134.7, 143.2);
    ctx.bezierCurveTo(134.4, 143.2, 134.1, 143.1, 134.0, 142.8);
    ctx.lineTo(128.1, 133.7);
    ctx.lineTo(128.1, 133.7);
    ctx.bezierCurveTo(124.9, 134.9, 121.4, 135.3, 118.0, 134.8);
    ctx.bezierCurveTo(111.2, 133.7, 103.4, 128.4, 101.8, 120.3);
    ctx.bezierCurveTo(100.3, 113.1, 106.3, 108.9, 107.0, 108.4);
    ctx.bezierCurveTo(114.8, 103.3, 124.2, 103.0, 135.2, 107.6);
    ctx.bezierCurveTo(136.6, 108.2, 146.3, 114.4, 144.3, 122.8);
    ctx.bezierCurveTo(142.9, 128.5, 139.7, 129.9, 137.5, 130.8);
    ctx.bezierCurveTo(137.2, 130.9, 136.9, 131.0, 136.7, 131.2);
    ctx.bezierCurveTo(136.4, 131.3, 136.2, 131.7, 136.2, 132.0);
    ctx.lineTo(135.7, 142.4);
    ctx.bezierCurveTo(135.6, 142.9, 135.2, 143.2, 134.7, 143.2);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(128.9, 133.1);
    ctx.lineTo(134.5, 141.9);
    ctx.lineTo(135.0, 131.9);
    ctx.bezierCurveTo(135.0, 131.2, 135.4, 130.6, 136.1, 130.3);
    ctx.lineTo(137.0, 129.9);
    ctx.bezierCurveTo(139.1, 129.0, 142.0, 127.8, 143.2, 122.6);
    ctx.bezierCurveTo(145.0, 114.9, 136.1, 109.1, 134.7, 108.6);
    ctx.bezierCurveTo(124.0, 104.2, 114.9, 104.4, 107.4, 109.3);
    ctx.bezierCurveTo(106.8, 109.7, 101.3, 113.5, 102.6, 120.1);
    ctx.bezierCurveTo(104.2, 127.8, 111.5, 132.8, 118.0, 133.8);
    ctx.bezierCurveTo(121.2, 134.3, 124.6, 133.9, 127.6, 132.7);
    ctx.bezierCurveTo(128.1, 132.6, 128.6, 132.8, 128.9, 133.1);
    ctx.lineTo(128.9, 133.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(132.9, 121.3);
    ctx.bezierCurveTo(133.1, 120.6, 133.9, 120.1, 134.7, 120.3);
    ctx.bezierCurveTo(135.5, 120.5, 136.0, 121.3, 135.9, 122.0);
    ctx.bezierCurveTo(135.7, 122.8, 134.9, 123.2, 134.1, 123.0);
    ctx.bezierCurveTo(133.3, 122.8, 132.8, 122.1, 132.9, 121.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(121.6, 120.8);
    ctx.bezierCurveTo(121.8, 120.0, 122.6, 119.6, 123.4, 119.7);
    ctx.bezierCurveTo(124.2, 119.9, 124.7, 120.7, 124.5, 121.5);
    ctx.bezierCurveTo(124.3, 122.2, 123.5, 122.7, 122.7, 122.5);
    ctx.bezierCurveTo(121.9, 122.3, 121.4, 121.5, 121.6, 120.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(111.1, 119.8);
    ctx.bezierCurveTo(111.3, 119.0, 112.1, 118.6, 112.9, 118.7);
    ctx.bezierCurveTo(113.7, 118.9, 114.2, 119.7, 114.0, 120.5);
    ctx.bezierCurveTo(113.9, 121.2, 113.1, 121.7, 112.2, 121.5);
    ctx.bezierCurveTo(111.4, 121.3, 110.9, 120.5, 111.1, 119.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(221.6, 393.7);
    ctx.bezierCurveTo(221.3, 393.7, 221.1, 393.6, 220.9, 393.3);
    ctx.lineTo(215.6, 384.2);
    ctx.lineTo(215.6, 384.2);
    ctx.bezierCurveTo(212.7, 385.4, 209.5, 385.8, 206.4, 385.3);
    ctx.bezierCurveTo(200.3, 384.2, 193.2, 378.9, 191.7, 370.8);
    ctx.bezierCurveTo(190.4, 363.6, 195.8, 359.4, 196.5, 358.9);
    ctx.bezierCurveTo(203.5, 353.8, 212.0, 353.5, 222.0, 358.1);
    ctx.bezierCurveTo(223.3, 358.7, 232.1, 364.9, 230.3, 373.3);
    ctx.bezierCurveTo(229.0, 379.0, 226.1, 380.4, 224.1, 381.3);
    ctx.bezierCurveTo(223.8, 381.4, 223.6, 381.5, 223.4, 381.7);
    ctx.bezierCurveTo(223.1, 381.9, 222.9, 382.2, 222.9, 382.5);
    ctx.lineTo(222.5, 392.9);
    ctx.bezierCurveTo(222.3, 393.4, 222.0, 393.7, 221.6, 393.7);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(216.3, 383.6);
    ctx.lineTo(221.4, 392.4);
    ctx.lineTo(221.9, 382.4);
    ctx.bezierCurveTo(221.8, 381.7, 222.2, 381.1, 222.9, 380.8);
    ctx.lineTo(223.7, 380.4);
    ctx.bezierCurveTo(225.6, 379.5, 228.2, 378.3, 229.3, 373.1);
    ctx.bezierCurveTo(230.9, 365.4, 222.9, 359.6, 221.6, 359.1);
    ctx.bezierCurveTo(211.9, 354.7, 203.6, 354.9, 196.8, 359.8);
    ctx.bezierCurveTo(193.5, 362.3, 191.8, 366.5, 192.5, 370.6);
    ctx.bezierCurveTo(193.9, 377.6, 199.5, 383.0, 206.5, 384.3);
    ctx.bezierCurveTo(209.4, 384.8, 212.4, 384.4, 215.2, 383.2);
    ctx.bezierCurveTo(215.6, 383.1, 216.1, 383.3, 216.4, 383.6);
    ctx.lineTo(216.3, 383.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(220.8, 370.9);
    ctx.bezierCurveTo(221.5, 370.6, 222.3, 371.0, 222.6, 371.7);
    ctx.bezierCurveTo(222.8, 372.4, 222.5, 373.2, 221.8, 373.5);
    ctx.bezierCurveTo(221.1, 373.8, 220.3, 373.4, 220.0, 372.7);
    ctx.bezierCurveTo(219.8, 371.9, 220.1, 371.1, 220.8, 370.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(210.5, 370.3);
    ctx.bezierCurveTo(211.2, 370.0, 212.0, 370.4, 212.3, 371.1);
    ctx.bezierCurveTo(212.5, 371.9, 212.2, 372.7, 211.5, 372.9);
    ctx.bezierCurveTo(210.8, 373.2, 210.0, 372.8, 209.7, 372.1);
    ctx.bezierCurveTo(209.5, 371.3, 209.8, 370.5, 210.5, 370.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(201.0, 369.3);
    ctx.bezierCurveTo(201.7, 369.0, 202.5, 369.4, 202.8, 370.1);
    ctx.bezierCurveTo(203.1, 370.9, 202.7, 371.7, 202.0, 371.9);
    ctx.bezierCurveTo(201.3, 372.2, 200.5, 371.8, 200.3, 371.1);
    ctx.bezierCurveTo(200.0, 370.3, 200.3, 369.5, 201.0, 369.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(395.6, 277.9);
    ctx.bezierCurveTo(395.4, 277.9, 395.2, 277.7, 395.1, 277.5);
    ctx.lineTo(390.6, 270.0);
    ctx.lineTo(390.6, 270.0);
    ctx.bezierCurveTo(388.2, 271.0, 385.6, 271.3, 383.0, 270.9);
    ctx.bezierCurveTo(377.9, 270.0, 372.0, 265.6, 370.9, 258.9);
    ctx.bezierCurveTo(369.7, 252.9, 374.2, 249.5, 374.8, 249.0);
    ctx.bezierCurveTo(380.6, 244.8, 387.7, 244.6, 396.0, 248.4);
    ctx.bezierCurveTo(397.0, 248.9, 404.3, 254.0, 402.8, 261.0);
    ctx.bezierCurveTo(401.8, 265.7, 399.4, 266.9, 397.7, 267.6);
    ctx.bezierCurveTo(397.5, 267.7, 397.3, 267.8, 397.1, 267.9);
    ctx.bezierCurveTo(396.8, 268.1, 396.7, 268.3, 396.7, 268.6);
    ctx.lineTo(396.3, 277.2);
    ctx.bezierCurveTo(396.2, 277.6, 396.0, 277.9, 395.6, 277.9);
    ctx.lineTo(395.6, 277.9);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(391.2, 269.5);
    ctx.lineTo(395.4, 276.8);
    ctx.lineTo(395.8, 268.5);
    ctx.bezierCurveTo(395.8, 267.9, 396.1, 267.4, 396.6, 267.2);
    ctx.lineTo(397.3, 266.8);
    ctx.bezierCurveTo(398.9, 266.1, 401.1, 265.1, 402.0, 260.8);
    ctx.bezierCurveTo(403.3, 254.4, 396.6, 249.6, 395.6, 249.2);
    ctx.bezierCurveTo(387.6, 245.5, 380.7, 245.7, 375.1, 249.8);
    ctx.bezierCurveTo(372.3, 251.8, 370.9, 255.3, 371.5, 258.7);
    ctx.bezierCurveTo(372.7, 264.5, 377.2, 269.0, 383.0, 270.1);
    ctx.bezierCurveTo(385.4, 270.5, 387.9, 270.2, 390.2, 269.2);
    ctx.bezierCurveTo(390.6, 269.1, 391.0, 269.2, 391.2, 269.5);
    ctx.lineTo(391.2, 269.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(395.0, 258.9);
    ctx.bezierCurveTo(395.5, 258.7, 396.2, 259.0, 396.4, 259.6);
    ctx.bezierCurveTo(396.6, 260.2, 396.3, 260.9, 395.8, 261.1);
    ctx.bezierCurveTo(395.2, 261.3, 394.5, 261.0, 394.3, 260.4);
    ctx.bezierCurveTo(394.1, 259.8, 394.4, 259.1, 395.0, 258.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(386.4, 258.4);
    ctx.bezierCurveTo(387.0, 258.2, 387.7, 258.5, 387.9, 259.1);
    ctx.bezierCurveTo(388.1, 259.7, 387.8, 260.4, 387.2, 260.6);
    ctx.bezierCurveTo(386.7, 260.8, 386.0, 260.5, 385.8, 259.9);
    ctx.bezierCurveTo(385.6, 259.3, 385.8, 258.6, 386.4, 258.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(378.5, 257.6);
    ctx.bezierCurveTo(379.1, 257.4, 379.8, 257.7, 380.0, 258.3);
    ctx.bezierCurveTo(380.2, 258.9, 379.9, 259.6, 379.4, 259.8);
    ctx.bezierCurveTo(378.8, 260.0, 378.1, 259.7, 377.9, 259.1);
    ctx.bezierCurveTo(377.7, 258.5, 378.0, 257.8, 378.5, 257.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(224.6, 307.0);
    ctx.bezierCurveTo(224.3, 307.0, 224.1, 306.9, 224.0, 306.7);
    ctx.lineTo(219.4, 299.9);
    ctx.lineTo(219.4, 299.9);
    ctx.bezierCurveTo(216.8, 300.9, 214.1, 301.1, 211.4, 300.8);
    ctx.bezierCurveTo(206.1, 299.9, 199.9, 296.0, 198.7, 289.9);
    ctx.bezierCurveTo(197.5, 284.6, 202.2, 281.4, 202.8, 281.0);
    ctx.bezierCurveTo(208.9, 277.2, 216.3, 277.0, 224.9, 280.4);
    ctx.bezierCurveTo(226.0, 280.9, 233.7, 285.5, 232.1, 291.8);
    ctx.bezierCurveTo(231.6, 294.6, 229.5, 297.0, 226.8, 297.8);
    ctx.bezierCurveTo(226.5, 297.9, 226.3, 298.0, 226.1, 298.1);
    ctx.bezierCurveTo(225.9, 298.2, 225.7, 298.4, 225.7, 298.7);
    ctx.lineTo(225.3, 306.5);
    ctx.bezierCurveTo(225.2, 306.8, 224.9, 307.1, 224.6, 307.1);
    ctx.lineTo(224.6, 307.0);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(220.0, 299.5);
    ctx.lineTo(224.4, 306.1);
    ctx.lineTo(224.8, 298.6);
    ctx.bezierCurveTo(224.8, 298.1, 225.2, 297.6, 225.7, 297.4);
    ctx.lineTo(226.4, 297.1);
    ctx.bezierCurveTo(228.9, 296.4, 230.8, 294.2, 231.3, 291.6);
    ctx.bezierCurveTo(232.7, 285.9, 225.7, 281.6, 224.6, 281.2);
    ctx.bezierCurveTo(216.2, 277.9, 209.0, 278.1, 203.1, 281.7);
    ctx.bezierCurveTo(202.6, 282.0, 198.3, 284.8, 199.3, 289.8);
    ctx.bezierCurveTo(200.6, 295.5, 206.3, 299.3, 211.4, 300.0);
    ctx.bezierCurveTo(214.0, 300.4, 216.6, 300.1, 219.0, 299.2);
    ctx.bezierCurveTo(219.4, 299.1, 219.7, 299.2, 220.0, 299.5);
    ctx.lineTo(220.0, 299.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(223.1, 290.8);
    ctx.bezierCurveTo(223.2, 290.2, 223.8, 289.8, 224.4, 289.9);
    ctx.bezierCurveTo(225.1, 290.0, 225.5, 290.5, 225.5, 291.1);
    ctx.bezierCurveTo(225.4, 291.7, 224.8, 292.0, 224.2, 292.0);
    ctx.bezierCurveTo(223.5, 291.9, 223.1, 291.3, 223.1, 290.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(214.2, 290.3);
    ctx.bezierCurveTo(214.3, 289.8, 214.8, 289.4, 215.5, 289.5);
    ctx.bezierCurveTo(216.1, 289.6, 216.6, 290.1, 216.5, 290.7);
    ctx.bezierCurveTo(216.4, 291.2, 215.9, 291.6, 215.2, 291.5);
    ctx.bezierCurveTo(214.6, 291.5, 214.1, 290.9, 214.2, 290.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(205.9, 289.6);
    ctx.bezierCurveTo(206.0, 289.0, 206.6, 288.6, 207.2, 288.7);
    ctx.bezierCurveTo(207.9, 288.8, 208.4, 289.3, 208.3, 289.9);
    ctx.bezierCurveTo(208.2, 290.5, 207.6, 290.9, 207.0, 290.8);
    ctx.bezierCurveTo(206.3, 290.7, 205.9, 290.2, 205.9, 289.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(340.3, 405.2);
    ctx.bezierCurveTo(331.7, 401.8, 324.3, 402.0, 318.1, 405.8);
    ctx.bezierCurveTo(317.6, 406.1, 313.1, 409.1, 314.0, 414.2);
    ctx.lineTo(314.7, 414.2);
    ctx.bezierCurveTo(313.8, 409.5, 318.0, 406.7, 318.5, 406.4);
    ctx.bezierCurveTo(324.4, 402.8, 331.5, 402.6, 340.0, 405.9);
    ctx.bezierCurveTo(340.9, 406.3, 346.4, 409.6, 346.8, 414.2);
    ctx.lineTo(347.7, 414.2);
    ctx.bezierCurveTo(347.2, 409.2, 341.3, 405.6, 340.3, 405.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(331.1, 414.2);
    ctx.lineTo(330.3, 414.2);
    ctx.bezierCurveTo(330.5, 414.2, 330.7, 414.2, 330.9, 414.2);
    ctx.bezierCurveTo(330.9, 414.2, 331.0, 414.2, 331.1, 414.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(323.6, 414.2);
    ctx.lineTo(321.3, 414.2);
    ctx.bezierCurveTo(321.5, 413.7, 322.0, 413.4, 322.6, 413.4);
    ctx.bezierCurveTo(323.1, 413.5, 323.5, 413.8, 323.6, 414.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(307.8, 0.2);
    ctx.bezierCurveTo(306.8, 1.7, 305.2, 2.8, 303.3, 3.2);
    ctx.bezierCurveTo(301.8, 3.5, 300.3, 3.4, 299.0, 3.0);
    ctx.bezierCurveTo(299.0, 2.9, 299.0, 2.9, 298.9, 2.9);
    ctx.bezierCurveTo(298.7, 2.8, 298.4, 3.0, 298.3, 3.3);
    ctx.lineTo(296.3, 7.4);
    ctx.lineTo(295.6, 2.8);
    ctx.bezierCurveTo(295.5, 2.4, 295.3, 2.1, 295.0, 2.0);
    ctx.lineTo(294.5, 1.8);
    ctx.bezierCurveTo(293.6, 1.5, 292.8, 0.9, 292.2, 0.2);
    ctx.lineTo(291.4, 0.2);
    ctx.bezierCurveTo(292.1, 1.3, 293.1, 2.1, 294.3, 2.5);
    ctx.bezierCurveTo(294.5, 2.6, 294.6, 2.7, 294.8, 2.7);
    ctx.bezierCurveTo(294.9, 2.7, 294.9, 2.8, 295.0, 3.0);
    ctx.lineTo(295.8, 8.0);
    ctx.bezierCurveTo(295.8, 8.3, 296.0, 8.5, 296.2, 8.5);
    ctx.bezierCurveTo(296.3, 8.5, 296.4, 8.5, 296.4, 8.5);
    ctx.bezierCurveTo(296.5, 8.5, 296.7, 8.4, 296.7, 8.3);
    ctx.lineTo(298.8, 3.7);
    ctx.bezierCurveTo(300.3, 4.2, 301.9, 4.3, 303.5, 3.9);
    ctx.bezierCurveTo(305.7, 3.4, 307.5, 2.0, 308.7, 0.2);
    ctx.lineTo(307.8, 0.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(347.7, 0.2);
    ctx.lineTo(346.8, 0.2);
    ctx.bezierCurveTo(346.9, 0.9, 346.8, 1.6, 346.7, 2.4);
    ctx.bezierCurveTo(346.2, 5.0, 344.3, 7.1, 341.8, 7.8);
    ctx.lineTo(341.1, 8.1);
    ctx.bezierCurveTo(340.5, 8.3, 340.2, 8.8, 340.2, 9.3);
    ctx.lineTo(339.8, 16.8);
    ctx.lineTo(335.4, 10.2);
    ctx.bezierCurveTo(335.1, 10.0, 334.8, 9.9, 334.4, 9.9);
    ctx.bezierCurveTo(332.0, 10.8, 329.4, 11.1, 326.8, 10.7);
    ctx.bezierCurveTo(321.7, 10.0, 316.0, 6.3, 314.7, 0.5);
    ctx.bezierCurveTo(314.7, 0.4, 314.7, 0.3, 314.6, 0.2);
    ctx.lineTo(314.0, 0.2);
    ctx.bezierCurveTo(314.0, 0.4, 314.0, 0.5, 314.0, 0.7);
    ctx.bezierCurveTo(315.3, 6.7, 321.4, 10.7, 326.8, 11.5);
    ctx.bezierCurveTo(327.5, 11.6, 328.3, 11.6, 329.1, 11.6);
    ctx.bezierCurveTo(331.0, 11.6, 332.9, 11.3, 334.7, 10.7);
    ctx.lineTo(339.4, 17.5);
    ctx.bezierCurveTo(339.5, 17.6, 339.7, 17.8, 339.9, 17.8);
    ctx.lineTo(339.9, 17.8);
    ctx.bezierCurveTo(340.3, 17.8, 340.6, 17.5, 340.7, 17.2);
    ctx.lineTo(341.1, 9.4);
    ctx.bezierCurveTo(341.1, 9.2, 341.2, 8.9, 341.5, 8.8);
    ctx.bezierCurveTo(341.7, 8.7, 341.9, 8.6, 342.1, 8.5);
    ctx.bezierCurveTo(344.9, 7.7, 347.0, 5.4, 347.5, 2.5);
    ctx.bezierCurveTo(347.7, 1.7, 347.7, 0.9, 347.7, 0.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(338.5, 1.5);
    ctx.bezierCurveTo(338.6, 0.9, 339.2, 0.5, 339.8, 0.6);
    ctx.bezierCurveTo(340.5, 0.7, 340.9, 1.2, 340.9, 1.8);
    ctx.bezierCurveTo(340.8, 2.4, 340.2, 2.8, 339.5, 2.7);
    ctx.bezierCurveTo(338.9, 2.6, 338.4, 2.1, 338.5, 1.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(331.9, 1.4);
    ctx.bezierCurveTo(331.8, 2.0, 331.2, 2.4, 330.6, 2.3);
    ctx.bezierCurveTo(329.9, 2.2, 329.5, 1.6, 329.6, 1.1);
    ctx.bezierCurveTo(329.6, 0.6, 330.0, 0.3, 330.5, 0.2);
    ctx.bezierCurveTo(330.6, 0.2, 330.7, 0.2, 330.9, 0.2);
    ctx.bezierCurveTo(330.9, 0.2, 330.9, 0.2, 331.0, 0.2);
    ctx.bezierCurveTo(331.5, 0.3, 332.0, 0.8, 331.9, 1.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(323.7, 0.6);
    ctx.bezierCurveTo(323.6, 1.2, 323.0, 1.6, 322.3, 1.5);
    ctx.bezierCurveTo(321.7, 1.4, 321.2, 0.9, 321.3, 0.3);
    ctx.bezierCurveTo(321.3, 0.3, 321.3, 0.2, 321.3, 0.2);
    ctx.lineTo(323.6, 0.2);
    ctx.bezierCurveTo(323.7, 0.3, 323.7, 0.5, 323.7, 0.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(151.4, 267.6);
    ctx.bezierCurveTo(151.1, 267.6, 151.0, 267.5, 150.9, 267.3);
    ctx.lineTo(146.7, 260.5);
    ctx.lineTo(146.7, 260.5);
    ctx.bezierCurveTo(144.4, 261.4, 141.9, 261.7, 139.5, 261.3);
    ctx.bezierCurveTo(134.7, 260.5, 129.2, 256.5, 128.0, 250.5);
    ctx.bezierCurveTo(127.0, 245.1, 131.2, 242.0, 131.7, 241.6);
    ctx.bezierCurveTo(137.2, 237.8, 143.9, 237.6, 151.7, 241.0);
    ctx.bezierCurveTo(152.7, 241.4, 159.6, 246.1, 158.2, 252.3);
    ctx.bezierCurveTo(157.2, 256.6, 154.9, 257.6, 153.3, 258.3);
    ctx.bezierCurveTo(153.1, 258.4, 152.9, 258.5, 152.8, 258.6);
    ctx.bezierCurveTo(152.5, 258.8, 152.4, 259.0, 152.4, 259.2);
    ctx.lineTo(152.1, 267.0);
    ctx.bezierCurveTo(151.9, 267.4, 151.7, 267.6, 151.4, 267.6);
    ctx.lineTo(151.4, 267.6);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(147.2, 260.0);
    ctx.lineTo(151.2, 266.6);
    ctx.lineTo(151.6, 259.1);
    ctx.bezierCurveTo(151.6, 258.6, 151.9, 258.1, 152.4, 257.9);
    ctx.lineTo(153.0, 257.6);
    ctx.bezierCurveTo(154.5, 257.0, 156.6, 256.1, 157.4, 252.2);
    ctx.bezierCurveTo(158.7, 246.4, 152.4, 242.1, 151.4, 241.7);
    ctx.bezierCurveTo(143.8, 238.4, 137.4, 238.6, 132.1, 242.3);
    ctx.bezierCurveTo(129.5, 244.1, 128.2, 247.2, 128.7, 250.3);
    ctx.bezierCurveTo(129.8, 256.1, 135.0, 259.8, 139.6, 260.6);
    ctx.bezierCurveTo(141.9, 260.9, 144.2, 260.6, 146.4, 259.7);
    ctx.bezierCurveTo(146.7, 259.7, 147.1, 259.8, 147.3, 260.0);
    ctx.lineTo(147.2, 260.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(150.3, 250.8);
    ctx.bezierCurveTo(150.6, 250.4, 151.3, 250.3, 151.8, 250.6);
    ctx.bezierCurveTo(152.2, 251.0, 152.3, 251.7, 152.0, 252.1);
    ctx.bezierCurveTo(151.7, 252.6, 151.0, 252.7, 150.5, 252.3);
    ctx.bezierCurveTo(150.0, 252.0, 149.9, 251.3, 150.3, 250.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(142.2, 250.4);
    ctx.bezierCurveTo(142.6, 250.0, 143.2, 249.9, 143.7, 250.3);
    ctx.bezierCurveTo(144.2, 250.6, 144.3, 251.3, 143.9, 251.7);
    ctx.bezierCurveTo(143.6, 252.2, 142.9, 252.3, 142.5, 251.9);
    ctx.bezierCurveTo(142.0, 251.6, 141.9, 250.9, 142.2, 250.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(134.8, 249.7);
    ctx.bezierCurveTo(135.1, 249.2, 135.8, 249.2, 136.3, 249.5);
    ctx.bezierCurveTo(136.8, 249.9, 136.9, 250.5, 136.5, 251.0);
    ctx.bezierCurveTo(136.2, 251.5, 135.5, 251.5, 135.0, 251.2);
    ctx.bezierCurveTo(134.6, 250.8, 134.5, 250.2, 134.8, 249.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(129.2, 355.2);
    ctx.bezierCurveTo(129.0, 355.2, 128.8, 355.1, 128.7, 354.9);
    ctx.lineTo(124.5, 348.1);
    ctx.lineTo(124.5, 348.1);
    ctx.bezierCurveTo(122.2, 349.0, 119.7, 349.3, 117.3, 348.9);
    ctx.bezierCurveTo(112.5, 348.1, 107.0, 344.1, 105.9, 338.1);
    ctx.bezierCurveTo(104.8, 332.7, 109.0, 329.6, 109.5, 329.2);
    ctx.bezierCurveTo(115.1, 325.4, 121.7, 325.2, 129.5, 328.6);
    ctx.bezierCurveTo(130.5, 329.1, 137.4, 333.7, 136.0, 340.0);
    ctx.bezierCurveTo(135.0, 344.2, 132.7, 345.3, 131.2, 346.0);
    ctx.bezierCurveTo(131.0, 346.0, 130.8, 346.1, 130.6, 346.3);
    ctx.bezierCurveTo(130.4, 346.4, 130.2, 346.6, 130.2, 346.9);
    ctx.lineTo(129.9, 354.6);
    ctx.bezierCurveTo(129.7, 355.0, 129.5, 355.2, 129.2, 355.2);
    ctx.lineTo(129.2, 355.2);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(125.1, 347.7);
    ctx.lineTo(129.1, 354.2);
    ctx.lineTo(129.4, 346.8);
    ctx.bezierCurveTo(129.4, 346.2, 129.7, 345.8, 130.2, 345.6);
    ctx.lineTo(130.8, 345.3);
    ctx.bezierCurveTo(132.3, 344.6, 134.4, 343.7, 135.2, 339.8);
    ctx.bezierCurveTo(136.5, 334.1, 130.2, 329.7, 129.2, 329.4);
    ctx.bezierCurveTo(121.6, 326.1, 115.2, 326.2, 109.9, 329.9);
    ctx.bezierCurveTo(107.3, 331.7, 106.0, 334.8, 106.5, 337.9);
    ctx.bezierCurveTo(107.6, 343.7, 112.8, 347.4, 117.4, 348.2);
    ctx.bezierCurveTo(119.7, 348.5, 122.0, 348.3, 124.2, 347.4);
    ctx.bezierCurveTo(124.5, 347.3, 124.9, 347.4, 125.1, 347.7);
    ctx.lineTo(125.1, 347.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(128.1, 338.5);
    ctx.bezierCurveTo(128.4, 338.0, 129.1, 337.9, 129.6, 338.3);
    ctx.bezierCurveTo(130.1, 338.6, 130.2, 339.3, 129.8, 339.8);
    ctx.bezierCurveTo(129.5, 340.2, 128.8, 340.3, 128.3, 339.9);
    ctx.bezierCurveTo(127.9, 339.6, 127.8, 338.9, 128.1, 338.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(120.0, 338.1);
    ctx.bezierCurveTo(120.4, 337.6, 121.0, 337.5, 121.5, 337.9);
    ctx.bezierCurveTo(122.0, 338.2, 122.1, 338.9, 121.7, 339.4);
    ctx.bezierCurveTo(121.4, 339.8, 120.7, 339.9, 120.3, 339.6);
    ctx.bezierCurveTo(119.8, 339.2, 119.7, 338.5, 120.0, 338.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(112.6, 337.3);
    ctx.bezierCurveTo(113.0, 336.9, 113.6, 336.8, 114.1, 337.2);
    ctx.bezierCurveTo(114.6, 337.5, 114.7, 338.2, 114.3, 338.6);
    ctx.bezierCurveTo(114.0, 339.1, 113.3, 339.2, 112.8, 338.8);
    ctx.bezierCurveTo(112.4, 338.5, 112.3, 337.8, 112.6, 337.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(77.9, 297.9);
    ctx.bezierCurveTo(77.7, 297.9, 77.5, 297.8, 77.4, 297.6);
    ctx.lineTo(73.6, 291.4);
    ctx.lineTo(73.6, 291.4);
    ctx.bezierCurveTo(71.5, 292.2, 69.2, 292.4, 67.0, 292.1);
    ctx.bezierCurveTo(62.6, 291.4, 57.5, 287.7, 56.4, 282.1);
    ctx.bezierCurveTo(55.4, 277.2, 59.3, 274.3, 59.8, 273.9);
    ctx.bezierCurveTo(64.9, 270.4, 71.0, 270.2, 78.2, 273.4);
    ctx.bezierCurveTo(79.1, 273.8, 85.5, 278.1, 84.2, 283.8);
    ctx.bezierCurveTo(83.3, 287.8, 81.2, 288.7, 79.8, 289.3);
    ctx.bezierCurveTo(79.6, 289.4, 79.4, 289.5, 79.3, 289.6);
    ctx.bezierCurveTo(79.0, 289.7, 78.9, 289.9, 78.9, 290.2);
    ctx.lineTo(78.6, 297.3);
    ctx.bezierCurveTo(78.5, 297.7, 78.3, 297.9, 78.0, 297.9);
    ctx.lineTo(77.9, 297.9);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(74.1, 290.9);
    ctx.lineTo(77.8, 297.0);
    ctx.lineTo(78.1, 290.1);
    ctx.bezierCurveTo(78.1, 289.6, 78.4, 289.2, 78.8, 289.0);
    ctx.lineTo(79.4, 288.7);
    ctx.bezierCurveTo(80.8, 288.1, 82.7, 287.3, 83.4, 283.7);
    ctx.bezierCurveTo(84.6, 278.4, 78.8, 274.4, 77.8, 274.1);
    ctx.bezierCurveTo(70.8, 271.1, 64.9, 271.2, 60.0, 274.6);
    ctx.bezierCurveTo(57.6, 276.3, 56.4, 279.1, 56.9, 282.0);
    ctx.bezierCurveTo(57.9, 287.3, 62.7, 290.8, 66.9, 291.4);
    ctx.bezierCurveTo(69.1, 291.8, 71.2, 291.5, 73.2, 290.7);
    ctx.bezierCurveTo(73.5, 290.6, 73.9, 290.7, 74.1, 291.0);
    ctx.lineTo(74.1, 290.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(76.9, 282.5);
    ctx.bezierCurveTo(77.2, 282.0, 77.8, 282.0, 78.3, 282.3);
    ctx.bezierCurveTo(78.7, 282.6, 78.8, 283.2, 78.5, 283.6);
    ctx.bezierCurveTo(78.2, 284.1, 77.6, 284.1, 77.1, 283.8);
    ctx.bezierCurveTo(76.7, 283.5, 76.6, 282.9, 76.9, 282.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(69.5, 282.1);
    ctx.bezierCurveTo(69.8, 281.7, 70.4, 281.6, 70.8, 281.9);
    ctx.bezierCurveTo(71.3, 282.3, 71.4, 282.9, 71.1, 283.3);
    ctx.bezierCurveTo(70.7, 283.7, 70.1, 283.8, 69.7, 283.5);
    ctx.bezierCurveTo(69.3, 283.1, 69.2, 282.5, 69.5, 282.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(62.6, 281.4);
    ctx.bezierCurveTo(63.0, 281.0, 63.6, 280.9, 64.0, 281.2);
    ctx.bezierCurveTo(64.4, 281.6, 64.5, 282.2, 64.2, 282.6);
    ctx.bezierCurveTo(63.9, 283.0, 63.3, 283.1, 62.9, 282.8);
    ctx.bezierCurveTo(62.4, 282.4, 62.3, 281.8, 62.6, 281.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.restore();
    ctx.beginPath();
    ctx.moveTo(10.6, 277.6);
    ctx.bezierCurveTo(7.3, 276.0, 3.6, 275.3, 0.0, 275.4);
    ctx.lineTo(0.0, 276.1);
    ctx.bezierCurveTo(3.5, 276.1, 7.0, 276.8, 10.2, 278.3);
    ctx.bezierCurveTo(11.1, 278.6, 17.0, 282.6, 15.8, 287.9);
    ctx.bezierCurveTo(15.0, 291.5, 13.1, 292.3, 11.8, 292.9);
    ctx.lineTo(11.2, 293.2);
    ctx.bezierCurveTo(10.8, 293.4, 10.5, 293.8, 10.5, 294.3);
    ctx.lineTo(10.1, 301.2);
    ctx.lineTo(6.5, 295.1);
    ctx.bezierCurveTo(6.2, 294.9, 5.9, 294.8, 5.6, 294.9);
    ctx.bezierCurveTo(3.8, 295.6, 1.9, 295.9, 0.0, 295.7);
    ctx.lineTo(0.0, 296.4);
    ctx.bezierCurveTo(0.4, 296.4, 0.8, 296.5, 1.2, 296.5);
    ctx.bezierCurveTo(2.8, 296.5, 4.4, 296.2, 5.9, 295.6);
    ctx.lineTo(9.8, 301.8);
    ctx.bezierCurveTo(9.9, 302.0, 10.0, 302.1, 10.2, 302.1);
    ctx.bezierCurveTo(10.6, 302.1, 10.8, 301.9, 10.9, 301.6);
    ctx.lineTo(11.2, 294.4);
    ctx.bezierCurveTo(11.2, 294.2, 11.3, 293.9, 11.5, 293.8);
    ctx.bezierCurveTo(11.7, 293.7, 11.9, 293.6, 12.1, 293.6);
    ctx.bezierCurveTo(13.5, 292.9, 15.6, 292.0, 16.5, 288.1);
    ctx.bezierCurveTo(17.8, 282.3, 11.5, 278.0, 10.6, 277.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(9.3, 286.7);
    ctx.bezierCurveTo(9.6, 286.2, 10.2, 286.2, 10.6, 286.5);
    ctx.bezierCurveTo(11.1, 286.8, 11.2, 287.4, 10.8, 287.9);
    ctx.bezierCurveTo(10.5, 288.3, 9.9, 288.4, 9.5, 288.0);
    ctx.bezierCurveTo(9.0, 287.7, 8.9, 287.1, 9.3, 286.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(1.8, 286.3);
    ctx.bezierCurveTo(2.1, 285.9, 2.7, 285.8, 3.2, 286.1);
    ctx.bezierCurveTo(3.6, 286.5, 3.7, 287.1, 3.4, 287.5);
    ctx.bezierCurveTo(3.1, 287.9, 2.5, 288.0, 2.0, 287.7);
    ctx.bezierCurveTo(1.6, 287.3, 1.5, 286.7, 1.8, 286.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(407.6, 278.8);
    ctx.bezierCurveTo(409.8, 277.2, 412.5, 276.3, 415.2, 276.1);
    ctx.lineTo(415.2, 275.4);
    ctx.bezierCurveTo(412.4, 275.6, 409.7, 276.5, 407.3, 278.1);
    ctx.bezierCurveTo(406.9, 278.5, 403.0, 281.4, 403.9, 286.3);
    ctx.bezierCurveTo(405.0, 291.9, 410.1, 295.6, 414.5, 296.3);
    ctx.bezierCurveTo(414.8, 296.3, 415.0, 296.4, 415.2, 296.4);
    ctx.lineTo(415.2, 295.7);
    ctx.bezierCurveTo(415.0, 295.7, 414.8, 295.7, 414.5, 295.6);
    ctx.bezierCurveTo(410.3, 295.0, 405.5, 291.5, 404.5, 286.2);
    ctx.bezierCurveTo(404.0, 283.3, 405.2, 280.4, 407.6, 278.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(410.2, 285.6);
    ctx.bezierCurveTo(410.5, 285.2, 411.1, 285.1, 411.6, 285.5);
    ctx.bezierCurveTo(412.0, 285.8, 412.1, 286.4, 411.8, 286.8);
    ctx.bezierCurveTo(411.5, 287.3, 410.8, 287.3, 410.4, 287.0);
    ctx.bezierCurveTo(410.0, 286.7, 409.9, 286.1, 410.2, 285.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(45.6, 314.6);
    ctx.bezierCurveTo(45.4, 314.6, 45.2, 314.5, 45.1, 314.3);
    ctx.lineTo(40.9, 307.5);
    ctx.lineTo(40.9, 307.5);
    ctx.bezierCurveTo(38.6, 308.4, 36.2, 308.7, 33.7, 308.3);
    ctx.bezierCurveTo(28.9, 307.5, 23.4, 303.5, 22.3, 297.5);
    ctx.bezierCurveTo(21.2, 292.1, 25.5, 288.9, 25.9, 288.6);
    ctx.bezierCurveTo(31.5, 284.8, 38.1, 284.6, 45.9, 288.0);
    ctx.bezierCurveTo(46.9, 288.4, 53.8, 293.1, 52.4, 299.3);
    ctx.bezierCurveTo(51.4, 303.6, 49.1, 304.6, 47.6, 305.3);
    ctx.bezierCurveTo(47.4, 305.4, 47.2, 305.5, 47.0, 305.6);
    ctx.bezierCurveTo(46.8, 305.7, 46.6, 306.0, 46.7, 306.2);
    ctx.lineTo(46.3, 314.0);
    ctx.bezierCurveTo(46.2, 314.4, 45.9, 314.6, 45.6, 314.6);
    ctx.lineTo(45.6, 314.6);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(41.5, 307.0);
    ctx.lineTo(45.5, 313.6);
    ctx.lineTo(45.8, 306.1);
    ctx.bezierCurveTo(45.8, 305.6, 46.1, 305.1, 46.6, 304.9);
    ctx.lineTo(47.2, 304.6);
    ctx.bezierCurveTo(48.7, 304.0, 50.8, 303.1, 51.6, 299.2);
    ctx.bezierCurveTo(52.9, 293.4, 46.6, 289.1, 45.6, 288.7);
    ctx.bezierCurveTo(38.0, 285.4, 31.6, 285.6, 26.3, 289.2);
    ctx.bezierCurveTo(23.7, 291.1, 22.4, 294.2, 22.9, 297.3);
    ctx.bezierCurveTo(24.0, 303.1, 29.2, 306.8, 33.8, 307.5);
    ctx.bezierCurveTo(36.1, 307.9, 38.5, 307.6, 40.6, 306.7);
    ctx.bezierCurveTo(40.9, 306.7, 41.3, 306.8, 41.5, 307.0);
    ctx.lineTo(41.5, 307.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(44.5, 297.8);
    ctx.bezierCurveTo(44.9, 297.4, 45.5, 297.3, 46.0, 297.6);
    ctx.bezierCurveTo(46.5, 298.0, 46.6, 298.7, 46.2, 299.1);
    ctx.bezierCurveTo(45.9, 299.6, 45.2, 299.7, 44.7, 299.3);
    ctx.bezierCurveTo(44.3, 298.9, 44.2, 298.3, 44.5, 297.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(36.4, 297.4);
    ctx.bezierCurveTo(36.8, 297.0, 37.4, 296.9, 37.9, 297.2);
    ctx.bezierCurveTo(38.4, 297.6, 38.5, 298.3, 38.2, 298.7);
    ctx.bezierCurveTo(37.8, 299.2, 37.1, 299.3, 36.7, 298.9);
    ctx.bezierCurveTo(36.2, 298.6, 36.1, 297.9, 36.4, 297.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(29.0, 296.7);
    ctx.bezierCurveTo(29.4, 296.2, 30.0, 296.1, 30.5, 296.5);
    ctx.bezierCurveTo(31.0, 296.9, 31.1, 297.5, 30.7, 298.0);
    ctx.bezierCurveTo(30.4, 298.4, 29.7, 298.5, 29.3, 298.2);
    ctx.bezierCurveTo(28.8, 297.8, 28.7, 297.1, 29.0, 296.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(28.8, 340.0);
    ctx.bezierCurveTo(28.6, 340.0, 28.5, 339.9, 28.4, 339.8);
    ctx.lineTo(24.8, 333.8);
    ctx.lineTo(24.8, 333.8);
    ctx.bezierCurveTo(22.8, 334.6, 20.7, 334.9, 18.6, 334.6);
    ctx.bezierCurveTo(14.4, 333.8, 9.6, 330.4, 8.6, 325.1);
    ctx.bezierCurveTo(7.7, 320.4, 11.4, 317.7, 11.8, 317.3);
    ctx.bezierCurveTo(16.6, 314.0, 22.4, 313.8, 29.1, 316.8);
    ctx.bezierCurveTo(30.0, 317.2, 35.9, 321.3, 34.7, 326.7);
    ctx.bezierCurveTo(33.8, 330.4, 31.9, 331.4, 30.5, 331.9);
    ctx.bezierCurveTo(30.3, 332.0, 30.1, 332.1, 30.0, 332.2);
    ctx.bezierCurveTo(29.8, 332.3, 29.7, 332.5, 29.7, 332.7);
    ctx.lineTo(29.4, 339.5);
    ctx.bezierCurveTo(29.3, 339.8, 29.1, 340.0, 28.8, 340.0);
    ctx.lineTo(28.8, 340.0);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(25.2, 333.4);
    ctx.lineTo(28.7, 339.2);
    ctx.lineTo(29.0, 332.7);
    ctx.bezierCurveTo(29.0, 332.3, 29.2, 331.9, 29.6, 331.7);
    ctx.lineTo(30.2, 331.4);
    ctx.bezierCurveTo(31.5, 330.8, 33.3, 330.1, 34.0, 326.7);
    ctx.bezierCurveTo(35.1, 321.7, 29.6, 317.9, 28.8, 317.5);
    ctx.bezierCurveTo(22.2, 314.7, 16.7, 314.8, 12.1, 318.0);
    ctx.bezierCurveTo(9.8, 319.6, 8.7, 322.3, 9.1, 325.0);
    ctx.bezierCurveTo(10.2, 329.6, 13.9, 333.1, 18.6, 333.9);
    ctx.bezierCurveTo(20.5, 334.2, 22.6, 334.0, 24.4, 333.2);
    ctx.bezierCurveTo(24.7, 333.1, 25.0, 333.2, 25.2, 333.5);
    ctx.lineTo(25.2, 333.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(28.0, 325.3);
    ctx.bezierCurveTo(28.3, 325.0, 28.9, 325.0, 29.3, 325.3);
    ctx.bezierCurveTo(29.6, 325.7, 29.6, 326.3, 29.3, 326.6);
    ctx.bezierCurveTo(28.9, 327.0, 28.3, 327.0, 28.0, 326.6);
    ctx.bezierCurveTo(27.6, 326.2, 27.6, 325.7, 28.0, 325.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(21.0, 325.0);
    ctx.bezierCurveTo(21.3, 324.6, 21.9, 324.6, 22.3, 325.0);
    ctx.bezierCurveTo(22.6, 325.4, 22.6, 325.9, 22.3, 326.3);
    ctx.bezierCurveTo(21.9, 326.6, 21.3, 326.6, 21.0, 326.3);
    ctx.bezierCurveTo(20.6, 325.9, 20.6, 325.3, 21.0, 325.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(14.6, 324.3);
    ctx.bezierCurveTo(14.9, 324.0, 15.5, 324.0, 15.9, 324.4);
    ctx.bezierCurveTo(16.2, 324.7, 16.2, 325.3, 15.9, 325.7);
    ctx.bezierCurveTo(15.5, 326.0, 14.9, 326.0, 14.6, 325.6);
    ctx.bezierCurveTo(14.2, 325.3, 14.2, 324.7, 14.6, 324.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(37.0, 372.9);
    ctx.bezierCurveTo(36.8, 372.9, 36.7, 372.8, 36.6, 372.7);
    ctx.lineTo(33.0, 366.8);
    ctx.lineTo(33.0, 366.8);
    ctx.bezierCurveTo(31.0, 367.5, 28.9, 367.8, 26.8, 367.5);
    ctx.bezierCurveTo(22.6, 366.8, 17.9, 363.3, 16.9, 358.0);
    ctx.bezierCurveTo(16.0, 353.3, 19.6, 350.6, 20.1, 350.3);
    ctx.bezierCurveTo(24.9, 346.9, 30.6, 346.7, 37.3, 349.7);
    ctx.bezierCurveTo(38.2, 350.1, 44.1, 354.2, 42.9, 359.6);
    ctx.bezierCurveTo(42.1, 363.4, 40.1, 364.3, 38.8, 364.9);
    ctx.bezierCurveTo(38.6, 364.9, 38.4, 365.0, 38.3, 365.1);
    ctx.bezierCurveTo(38.1, 365.2, 37.9, 365.4, 38.0, 365.6);
    ctx.lineTo(37.7, 372.4);
    ctx.bezierCurveTo(37.5, 372.7, 37.3, 372.9, 37.0, 372.9);
    ctx.lineTo(37.0, 372.9);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(33.5, 366.4);
    ctx.lineTo(36.9, 372.1);
    ctx.lineTo(37.2, 365.6);
    ctx.bezierCurveTo(37.2, 365.1, 37.5, 364.8, 37.9, 364.6);
    ctx.lineTo(38.4, 364.3);
    ctx.bezierCurveTo(39.7, 363.7, 41.5, 362.9, 42.2, 359.6);
    ctx.bezierCurveTo(43.3, 354.6, 37.9, 350.8, 37.0, 350.4);
    ctx.bezierCurveTo(30.5, 347.6, 24.9, 347.7, 20.3, 350.9);
    ctx.bezierCurveTo(18.0, 352.5, 16.9, 355.2, 17.3, 357.9);
    ctx.bezierCurveTo(18.4, 362.5, 22.1, 366.0, 26.8, 366.8);
    ctx.bezierCurveTo(28.8, 367.1, 30.8, 366.9, 32.7, 366.1);
    ctx.bezierCurveTo(32.9, 366.0, 33.2, 366.1, 33.5, 366.4);
    ctx.lineTo(33.5, 366.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(36.2, 358.2);
    ctx.bezierCurveTo(36.5, 357.9, 37.1, 357.9, 37.5, 358.3);
    ctx.bezierCurveTo(37.8, 358.6, 37.8, 359.2, 37.5, 359.5);
    ctx.bezierCurveTo(37.1, 359.9, 36.6, 359.9, 36.2, 359.5);
    ctx.bezierCurveTo(35.8, 359.1, 35.8, 358.6, 36.2, 358.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(29.2, 357.9);
    ctx.bezierCurveTo(29.6, 357.5, 30.1, 357.5, 30.5, 357.9);
    ctx.bezierCurveTo(30.9, 358.3, 30.9, 358.9, 30.5, 359.2);
    ctx.bezierCurveTo(30.1, 359.6, 29.6, 359.5, 29.2, 359.2);
    ctx.bezierCurveTo(28.8, 358.8, 28.8, 358.2, 29.2, 357.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(22.8, 357.2);
    ctx.bezierCurveTo(23.1, 356.9, 23.7, 356.9, 24.1, 357.3);
    ctx.bezierCurveTo(24.4, 357.6, 24.5, 358.2, 24.1, 358.6);
    ctx.bezierCurveTo(23.7, 358.9, 23.2, 358.9, 22.8, 358.5);
    ctx.bezierCurveTo(22.4, 358.2, 22.4, 357.6, 22.8, 357.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(48.0, 409.3);
    ctx.bezierCurveTo(47.8, 409.2, 47.6, 409.1, 47.5, 408.9);
    ctx.lineTo(43.5, 401.8);
    ctx.lineTo(43.5, 401.8);
    ctx.bezierCurveTo(41.4, 402.8, 39.0, 403.1, 36.7, 402.7);
    ctx.bezierCurveTo(31.1, 401.5, 26.7, 397.0, 25.7, 391.4);
    ctx.bezierCurveTo(25.1, 387.9, 26.4, 384.3, 29.2, 382.1);
    ctx.bezierCurveTo(34.5, 378.1, 40.9, 377.9, 48.3, 381.4);
    ctx.bezierCurveTo(49.3, 381.9, 55.9, 386.8, 54.5, 393.3);
    ctx.bezierCurveTo(53.5, 397.8, 51.4, 398.9, 49.9, 399.6);
    ctx.bezierCurveTo(49.7, 399.6, 49.5, 399.7, 49.4, 399.9);
    ctx.bezierCurveTo(49.1, 400.0, 49.0, 400.3, 49.0, 400.5);
    ctx.lineTo(48.7, 408.6);
    ctx.bezierCurveTo(48.6, 409.0, 48.3, 409.3, 48.0, 409.3);
    ctx.lineTo(48.0, 409.3);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(44.1, 401.4);
    ctx.lineTo(47.9, 408.2);
    ctx.lineTo(48.2, 400.4);
    ctx.bezierCurveTo(48.2, 399.9, 48.5, 399.4, 49.0, 399.2);
    ctx.lineTo(49.6, 398.9);
    ctx.bezierCurveTo(51.0, 398.2, 53.0, 397.2, 53.8, 393.2);
    ctx.bezierCurveTo(55.0, 387.1, 49.0, 382.6, 48.0, 382.2);
    ctx.bezierCurveTo(40.7, 378.8, 34.6, 378.9, 29.5, 382.8);
    ctx.bezierCurveTo(26.9, 384.8, 25.7, 388.0, 26.2, 391.2);
    ctx.bezierCurveTo(27.2, 396.6, 31.4, 400.8, 36.7, 401.9);
    ctx.bezierCurveTo(38.9, 402.3, 41.2, 402.0, 43.2, 401.0);
    ctx.bezierCurveTo(43.6, 401.0, 43.9, 401.1, 44.1, 401.4);
    ctx.lineTo(44.1, 401.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(47.6, 391.4);
    ctx.bezierCurveTo(48.2, 391.2, 48.7, 391.6, 48.8, 392.2);
    ctx.bezierCurveTo(48.9, 392.8, 48.6, 393.4, 48.0, 393.5);
    ctx.bezierCurveTo(47.5, 393.6, 46.9, 393.2, 46.8, 392.6);
    ctx.bezierCurveTo(46.7, 392.0, 47.1, 391.5, 47.6, 391.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(39.9, 390.9);
    ctx.bezierCurveTo(40.5, 390.8, 41.0, 391.2, 41.1, 391.8);
    ctx.bezierCurveTo(41.2, 392.4, 40.9, 393.0, 40.3, 393.1);
    ctx.bezierCurveTo(39.8, 393.2, 39.2, 392.8, 39.1, 392.2);
    ctx.bezierCurveTo(39.0, 391.6, 39.4, 391.0, 39.9, 390.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(32.8, 390.1);
    ctx.bezierCurveTo(33.4, 390.0, 33.9, 390.4, 34.0, 391.0);
    ctx.bezierCurveTo(34.1, 391.6, 33.8, 392.2, 33.2, 392.3);
    ctx.bezierCurveTo(32.7, 392.4, 32.1, 392.0, 32.0, 391.4);
    ctx.bezierCurveTo(31.9, 390.8, 32.3, 390.2, 32.8, 390.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(138.0, 394.8);
    ctx.bezierCurveTo(137.8, 394.8, 137.6, 394.6, 137.5, 394.4);
    ctx.lineTo(132.9, 386.9);
    ctx.lineTo(132.9, 386.9);
    ctx.bezierCurveTo(130.4, 387.9, 127.8, 388.2, 125.1, 387.8);
    ctx.bezierCurveTo(119.9, 386.9, 113.9, 382.5, 112.6, 375.8);
    ctx.bezierCurveTo(111.5, 369.8, 116.1, 366.4, 116.6, 366.0);
    ctx.bezierCurveTo(122.6, 361.7, 129.9, 361.5, 138.4, 365.3);
    ctx.bezierCurveTo(139.5, 365.8, 146.9, 370.9, 145.4, 377.9);
    ctx.bezierCurveTo(144.3, 382.6, 141.8, 383.8, 140.1, 384.5);
    ctx.bezierCurveTo(139.9, 384.6, 139.7, 384.7, 139.5, 384.8);
    ctx.bezierCurveTo(139.3, 384.9, 139.1, 385.2, 139.1, 385.5);
    ctx.lineTo(138.7, 394.1);
    ctx.bezierCurveTo(138.6, 394.5, 138.4, 394.8, 138.0, 394.8);
    ctx.lineTo(138.0, 394.8);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(133.5, 386.4);
    ctx.lineTo(137.8, 393.7);
    ctx.lineTo(138.2, 385.4);
    ctx.bezierCurveTo(138.2, 384.8, 138.6, 384.3, 139.1, 384.1);
    ctx.lineTo(139.8, 383.8);
    ctx.bezierCurveTo(141.4, 383.0, 143.6, 382.0, 144.6, 377.8);
    ctx.bezierCurveTo(145.9, 371.4, 139.1, 366.6, 138.0, 366.2);
    ctx.bezierCurveTo(129.8, 362.5, 122.7, 362.7, 116.9, 366.8);
    ctx.bezierCurveTo(114.1, 368.8, 112.7, 372.3, 113.2, 375.7);
    ctx.bezierCurveTo(114.5, 382.1, 120.1, 386.2, 125.1, 387.0);
    ctx.bezierCurveTo(127.6, 387.4, 130.2, 387.1, 132.5, 386.1);
    ctx.bezierCurveTo(132.9, 386.0, 133.3, 386.2, 133.5, 386.5);
    ctx.lineTo(133.5, 386.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(137.0, 376.0);
    ctx.bezierCurveTo(137.5, 375.6, 138.3, 375.7, 138.7, 376.3);
    ctx.bezierCurveTo(139.1, 376.8, 139.0, 377.5, 138.5, 377.9);
    ctx.bezierCurveTo(138.0, 378.3, 137.2, 378.2, 136.8, 377.6);
    ctx.bezierCurveTo(136.4, 377.1, 136.5, 376.4, 137.0, 376.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(128.3, 375.6);
    ctx.bezierCurveTo(128.8, 375.2, 129.5, 375.3, 129.9, 375.8);
    ctx.bezierCurveTo(130.3, 376.3, 130.2, 377.1, 129.7, 377.5);
    ctx.bezierCurveTo(129.2, 377.8, 128.5, 377.7, 128.1, 377.2);
    ctx.bezierCurveTo(127.7, 376.7, 127.8, 375.9, 128.3, 375.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(120.2, 374.7);
    ctx.bezierCurveTo(120.7, 374.4, 121.4, 374.5, 121.8, 375.0);
    ctx.bezierCurveTo(122.2, 375.5, 122.1, 376.3, 121.6, 376.6);
    ctx.bezierCurveTo(121.1, 377.0, 120.4, 376.9, 120.0, 376.4);
    ctx.bezierCurveTo(119.6, 375.9, 119.7, 375.1, 120.2, 374.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(184.9, 405.4);
    ctx.bezierCurveTo(184.7, 405.4, 184.5, 405.3, 184.4, 405.1);
    ctx.lineTo(179.8, 397.6);
    ctx.lineTo(179.8, 397.6);
    ctx.bezierCurveTo(177.3, 398.6, 174.7, 398.9, 172.0, 398.5);
    ctx.bezierCurveTo(166.8, 397.6, 160.8, 393.2, 159.5, 386.5);
    ctx.bezierCurveTo(158.4, 380.5, 163.0, 377.0, 163.5, 376.6);
    ctx.bezierCurveTo(169.5, 372.4, 176.8, 372.2, 185.3, 376.0);
    ctx.bezierCurveTo(186.4, 376.5, 193.8, 381.6, 192.3, 388.5);
    ctx.bezierCurveTo(191.2, 393.3, 188.7, 394.4, 187.0, 395.2);
    ctx.bezierCurveTo(186.8, 395.2, 186.6, 395.3, 186.4, 395.5);
    ctx.bezierCurveTo(186.2, 395.6, 186.0, 395.9, 186.0, 396.2);
    ctx.lineTo(185.6, 404.8);
    ctx.bezierCurveTo(185.5, 405.2, 185.3, 405.4, 184.9, 405.4);
    ctx.lineTo(184.9, 405.4);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(180.4, 397.0);
    ctx.lineTo(184.7, 404.3);
    ctx.lineTo(185.1, 396.0);
    ctx.bezierCurveTo(185.1, 395.5, 185.5, 394.9, 186.0, 394.7);
    ctx.lineTo(186.7, 394.4);
    ctx.bezierCurveTo(188.3, 393.6, 190.5, 392.7, 191.5, 388.4);
    ctx.bezierCurveTo(192.8, 382.0, 186.0, 377.2, 184.9, 376.8);
    ctx.bezierCurveTo(176.6, 373.2, 169.6, 373.3, 163.8, 377.4);
    ctx.bezierCurveTo(161.0, 379.4, 159.6, 382.9, 160.1, 386.3);
    ctx.bezierCurveTo(161.4, 392.7, 167.0, 396.8, 172.0, 397.7);
    ctx.bezierCurveTo(174.5, 398.1, 177.1, 397.7, 179.4, 396.7);
    ctx.bezierCurveTo(179.8, 396.7, 180.2, 396.8, 180.4, 397.1);
    ctx.lineTo(180.4, 397.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(184.0, 386.6);
    ctx.bezierCurveTo(184.5, 386.3, 185.2, 386.4, 185.6, 386.9);
    ctx.bezierCurveTo(186.0, 387.4, 185.9, 388.2, 185.4, 388.5);
    ctx.bezierCurveTo(184.9, 388.9, 184.2, 388.8, 183.8, 388.3);
    ctx.bezierCurveTo(183.4, 387.8, 183.5, 387.0, 184.0, 386.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(175.2, 386.2);
    ctx.bezierCurveTo(175.7, 385.8, 176.4, 385.9, 176.8, 386.5);
    ctx.bezierCurveTo(177.2, 387.0, 177.1, 387.7, 176.6, 388.1);
    ctx.bezierCurveTo(176.1, 388.5, 175.4, 388.4, 175.0, 387.8);
    ctx.bezierCurveTo(174.6, 387.3, 174.7, 386.6, 175.2, 386.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(167.1, 385.4);
    ctx.bezierCurveTo(167.6, 385.0, 168.3, 385.1, 168.7, 385.7);
    ctx.bezierCurveTo(169.1, 386.2, 169.0, 386.9, 168.5, 387.3);
    ctx.bezierCurveTo(168.0, 387.7, 167.3, 387.5, 166.9, 387.0);
    ctx.bezierCurveTo(166.5, 386.5, 166.6, 385.8, 167.1, 385.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(378.8, 378.7);
    ctx.bezierCurveTo(378.5, 378.7, 378.3, 378.5, 378.2, 378.3);
    ctx.lineTo(373.4, 369.9);
    ctx.lineTo(373.4, 369.9);
    ctx.bezierCurveTo(370.7, 371.0, 367.9, 371.4, 365.1, 370.9);
    ctx.bezierCurveTo(358.3, 369.5, 353.1, 364.2, 351.8, 357.5);
    ctx.bezierCurveTo(351.1, 353.3, 352.7, 349.1, 356.1, 346.5);
    ctx.bezierCurveTo(362.5, 341.7, 370.2, 341.5, 379.2, 345.7);
    ctx.bezierCurveTo(380.3, 346.3, 388.3, 352.0, 386.6, 359.8);
    ctx.bezierCurveTo(385.5, 365.1, 382.9, 366.4, 381.1, 367.2);
    ctx.bezierCurveTo(380.8, 367.3, 380.6, 367.4, 380.4, 367.6);
    ctx.bezierCurveTo(380.1, 367.7, 380.0, 368.0, 380.0, 368.3);
    ctx.lineTo(379.6, 378.0);
    ctx.bezierCurveTo(379.4, 378.4, 379.2, 378.7, 378.8, 378.7);
    ctx.lineTo(378.8, 378.7);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(374.0, 369.3);
    ctx.lineTo(378.6, 377.5);
    ctx.lineTo(379.0, 368.2);
    ctx.bezierCurveTo(379.0, 367.6, 379.3, 367.0, 379.9, 366.7);
    ctx.lineTo(380.6, 366.4);
    ctx.bezierCurveTo(382.4, 365.5, 384.7, 364.4, 385.7, 359.6);
    ctx.bezierCurveTo(387.2, 352.5, 379.9, 347.1, 378.7, 346.6);
    ctx.bezierCurveTo(369.9, 342.5, 362.5, 342.7, 356.3, 347.2);
    ctx.bezierCurveTo(353.3, 349.6, 351.8, 353.4, 352.4, 357.2);
    ctx.bezierCurveTo(353.7, 363.6, 358.6, 368.6, 365.0, 369.9);
    ctx.bezierCurveTo(367.7, 370.4, 370.4, 370.0, 372.9, 368.9);
    ctx.bezierCurveTo(373.3, 368.8, 373.7, 369.0, 374.0, 369.3);
    ctx.lineTo(374.0, 369.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(378.2, 357.5);
    ctx.bezierCurveTo(378.8, 357.3, 379.5, 357.8, 379.7, 358.5);
    ctx.bezierCurveTo(379.8, 359.2, 379.4, 359.9, 378.8, 360.1);
    ctx.bezierCurveTo(378.1, 360.2, 377.5, 359.8, 377.3, 359.1);
    ctx.bezierCurveTo(377.1, 358.4, 377.5, 357.7, 378.2, 357.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(368.9, 357.0);
    ctx.bezierCurveTo(369.5, 356.8, 370.2, 357.3, 370.4, 358.0);
    ctx.bezierCurveTo(370.5, 358.7, 370.1, 359.4, 369.5, 359.5);
    ctx.bezierCurveTo(368.8, 359.7, 368.2, 359.2, 368.0, 358.5);
    ctx.bezierCurveTo(367.8, 357.8, 368.2, 357.1, 368.9, 357.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(360.3, 356.0);
    ctx.bezierCurveTo(361.0, 355.9, 361.6, 356.3, 361.8, 357.0);
    ctx.bezierCurveTo(362.0, 357.7, 361.6, 358.4, 360.9, 358.6);
    ctx.bezierCurveTo(360.3, 358.7, 359.6, 358.3, 359.4, 357.6);
    ctx.bezierCurveTo(359.3, 356.9, 359.7, 356.2, 360.3, 356.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(264.0, 300.7);
    ctx.bezierCurveTo(263.8, 300.7, 263.6, 300.6, 263.5, 300.4);
    ctx.lineTo(259.3, 293.6);
    ctx.lineTo(259.3, 293.6);
    ctx.bezierCurveTo(257.0, 294.5, 254.6, 294.8, 252.2, 294.5);
    ctx.bezierCurveTo(247.3, 293.6, 241.8, 289.7, 240.7, 283.6);
    ctx.bezierCurveTo(239.6, 278.2, 243.9, 275.1, 244.4, 274.7);
    ctx.bezierCurveTo(249.9, 270.9, 256.6, 270.7, 264.4, 274.1);
    ctx.bezierCurveTo(265.4, 274.6, 272.2, 279.2, 270.8, 285.5);
    ctx.bezierCurveTo(269.8, 289.7, 267.6, 290.8, 266.0, 291.5);
    ctx.bezierCurveTo(265.8, 291.5, 265.6, 291.6, 265.4, 291.8);
    ctx.bezierCurveTo(265.2, 291.9, 265.0, 292.1, 265.1, 292.4);
    ctx.lineTo(264.7, 300.2);
    ctx.bezierCurveTo(264.6, 300.5, 264.4, 300.7, 264.0, 300.7);
    ctx.lineTo(264.0, 300.7);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(259.9, 293.2);
    ctx.lineTo(263.9, 299.8);
    ctx.lineTo(264.2, 292.3);
    ctx.bezierCurveTo(264.2, 291.8, 264.5, 291.3, 265.0, 291.1);
    ctx.lineTo(265.6, 290.8);
    ctx.bezierCurveTo(267.1, 290.1, 269.2, 289.2, 270.0, 285.4);
    ctx.bezierCurveTo(271.3, 279.6, 265.0, 275.3, 264.0, 274.9);
    ctx.bezierCurveTo(256.5, 271.6, 250.0, 271.8, 244.7, 275.4);
    ctx.bezierCurveTo(242.1, 277.2, 240.8, 280.4, 241.3, 283.5);
    ctx.bezierCurveTo(242.4, 289.2, 247.6, 293.0, 252.2, 293.7);
    ctx.bezierCurveTo(254.5, 294.1, 256.8, 293.8, 259.0, 292.9);
    ctx.bezierCurveTo(259.3, 292.8, 259.7, 292.9, 259.9, 293.2);
    ctx.lineTo(259.9, 293.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(262.9, 284.0);
    ctx.bezierCurveTo(263.2, 283.5, 263.9, 283.4, 264.4, 283.8);
    ctx.bezierCurveTo(264.9, 284.1, 265.0, 284.8, 264.6, 285.3);
    ctx.bezierCurveTo(264.3, 285.7, 263.6, 285.8, 263.1, 285.4);
    ctx.bezierCurveTo(262.7, 285.1, 262.6, 284.4, 262.9, 284.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(254.8, 283.6);
    ctx.bezierCurveTo(255.2, 283.1, 255.9, 283.0, 256.3, 283.4);
    ctx.bezierCurveTo(256.8, 283.8, 256.9, 284.4, 256.6, 284.9);
    ctx.bezierCurveTo(256.2, 285.3, 255.6, 285.4, 255.1, 285.1);
    ctx.bezierCurveTo(254.6, 284.7, 254.5, 284.0, 254.8, 283.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(247.4, 282.9);
    ctx.bezierCurveTo(247.8, 282.4, 248.4, 282.3, 248.9, 282.7);
    ctx.bezierCurveTo(249.4, 283.0, 249.5, 283.7, 249.1, 284.1);
    ctx.bezierCurveTo(248.8, 284.6, 248.1, 284.7, 247.7, 284.3);
    ctx.bezierCurveTo(247.2, 284.0, 247.1, 283.3, 247.4, 282.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(377.2, 229.5);
    ctx.bezierCurveTo(377.0, 229.5, 376.8, 229.4, 376.7, 229.2);
    ctx.lineTo(372.6, 222.4);
    ctx.lineTo(372.6, 222.4);
    ctx.bezierCurveTo(370.3, 223.3, 367.8, 223.6, 365.4, 223.2);
    ctx.bezierCurveTo(360.6, 222.4, 355.0, 218.4, 353.9, 212.4);
    ctx.bezierCurveTo(352.8, 207.0, 357.1, 203.9, 357.6, 203.5);
    ctx.bezierCurveTo(363.1, 199.7, 369.8, 199.5, 377.6, 202.9);
    ctx.bezierCurveTo(378.6, 203.3, 385.5, 208.0, 384.0, 214.2);
    ctx.bezierCurveTo(383.0, 218.5, 380.8, 219.5, 379.2, 220.2);
    ctx.bezierCurveTo(379.0, 220.3, 378.8, 220.4, 378.7, 220.5);
    ctx.bezierCurveTo(378.4, 220.6, 378.3, 220.9, 378.3, 221.1);
    ctx.lineTo(377.9, 228.9);
    ctx.bezierCurveTo(377.8, 229.3, 377.6, 229.5, 377.2, 229.5);
    ctx.lineTo(377.2, 229.5);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(373.1, 221.9);
    ctx.lineTo(377.1, 228.5);
    ctx.lineTo(377.5, 221.0);
    ctx.bezierCurveTo(377.5, 220.5, 377.8, 220.0, 378.3, 219.8);
    ctx.lineTo(378.9, 219.5);
    ctx.bezierCurveTo(380.4, 218.9, 382.4, 218.0, 383.3, 214.1);
    ctx.bezierCurveTo(384.6, 208.3, 378.3, 204.0, 377.3, 203.6);
    ctx.bezierCurveTo(369.7, 200.3, 363.3, 200.5, 357.9, 204.2);
    ctx.bezierCurveTo(355.3, 206.0, 354.0, 209.1, 354.5, 212.2);
    ctx.bezierCurveTo(355.7, 218.0, 360.8, 221.7, 365.5, 222.5);
    ctx.bezierCurveTo(367.7, 222.8, 370.1, 222.5, 372.2, 221.6);
    ctx.bezierCurveTo(372.6, 221.6, 372.9, 221.7, 373.2, 221.9);
    ctx.lineTo(373.1, 221.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(376.2, 212.7);
    ctx.bezierCurveTo(376.5, 212.3, 377.2, 212.2, 377.6, 212.5);
    ctx.bezierCurveTo(378.1, 212.9, 378.2, 213.6, 377.9, 214.0);
    ctx.bezierCurveTo(377.5, 214.5, 376.9, 214.6, 376.4, 214.2);
    ctx.bezierCurveTo(375.9, 213.8, 375.8, 213.2, 376.2, 212.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(368.1, 212.4);
    ctx.bezierCurveTo(368.5, 211.9, 369.1, 211.8, 369.6, 212.2);
    ctx.bezierCurveTo(370.1, 212.5, 370.2, 213.2, 369.8, 213.6);
    ctx.bezierCurveTo(369.5, 214.1, 368.8, 214.2, 368.3, 213.8);
    ctx.bezierCurveTo(367.9, 213.5, 367.8, 212.8, 368.1, 212.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(360.7, 211.6);
    ctx.bezierCurveTo(361.1, 211.1, 361.7, 211.1, 362.2, 211.4);
    ctx.bezierCurveTo(362.7, 211.8, 362.8, 212.4, 362.4, 212.9);
    ctx.bezierCurveTo(362.1, 213.3, 361.4, 213.4, 360.9, 213.1);
    ctx.bezierCurveTo(360.5, 212.7, 360.4, 212.1, 360.7, 211.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(21.0, 412.3);
    ctx.bezierCurveTo(20.8, 412.3, 20.7, 412.3, 20.6, 412.1);
    ctx.lineTo(17.7, 407.3);
    ctx.lineTo(17.7, 407.3);
    ctx.bezierCurveTo(16.1, 407.9, 14.3, 408.1, 12.6, 407.9);
    ctx.bezierCurveTo(9.2, 407.3, 5.3, 404.5, 4.5, 400.2);
    ctx.bezierCurveTo(3.7, 396.4, 6.7, 394.2, 7.1, 393.9);
    ctx.bezierCurveTo(11.0, 391.2, 15.7, 391.1, 21.2, 393.5);
    ctx.bezierCurveTo(21.9, 393.8, 26.8, 397.1, 25.8, 401.5);
    ctx.bezierCurveTo(25.1, 404.6, 23.5, 405.3, 22.4, 405.8);
    ctx.bezierCurveTo(22.2, 405.8, 22.1, 405.9, 22.0, 406.0);
    ctx.bezierCurveTo(21.8, 406.1, 21.7, 406.2, 21.7, 406.4);
    ctx.lineTo(21.5, 411.9);
    ctx.bezierCurveTo(21.4, 412.2, 21.2, 412.3, 21.0, 412.3);
    ctx.lineTo(21.0, 412.3);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(18.1, 407.0);
    ctx.lineTo(20.9, 411.6);
    ctx.lineTo(21.1, 406.4);
    ctx.bezierCurveTo(21.1, 406.0, 21.4, 405.7, 21.7, 405.5);
    ctx.lineTo(22.2, 405.3);
    ctx.bezierCurveTo(23.2, 404.8, 24.7, 404.2, 25.3, 401.4);
    ctx.bezierCurveTo(26.2, 397.4, 21.7, 394.3, 21.0, 394.0);
    ctx.bezierCurveTo(15.6, 391.7, 11.1, 391.8, 7.3, 394.4);
    ctx.bezierCurveTo(5.5, 395.7, 4.5, 397.9, 4.9, 400.1);
    ctx.bezierCurveTo(5.7, 404.2, 9.4, 406.8, 12.6, 407.4);
    ctx.bezierCurveTo(14.3, 407.6, 15.9, 407.4, 17.4, 406.8);
    ctx.bezierCurveTo(17.7, 406.7, 17.9, 406.8, 18.1, 407.0);
    ctx.lineTo(18.1, 407.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(20.2, 400.5);
    ctx.bezierCurveTo(20.5, 400.1, 20.9, 400.1, 21.3, 400.3);
    ctx.bezierCurveTo(21.6, 400.6, 21.7, 401.1, 21.4, 401.4);
    ctx.bezierCurveTo(21.2, 401.7, 20.7, 401.8, 20.4, 401.5);
    ctx.bezierCurveTo(20.0, 401.3, 20.0, 400.8, 20.2, 400.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(14.5, 400.2);
    ctx.bezierCurveTo(14.8, 399.9, 15.2, 399.8, 15.6, 400.1);
    ctx.bezierCurveTo(15.9, 400.3, 16.0, 400.8, 15.7, 401.1);
    ctx.bezierCurveTo(15.5, 401.4, 15.0, 401.5, 14.7, 401.2);
    ctx.bezierCurveTo(14.3, 401.0, 14.3, 400.5, 14.5, 400.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(9.3, 399.7);
    ctx.bezierCurveTo(9.5, 399.3, 10.0, 399.3, 10.3, 399.5);
    ctx.bezierCurveTo(10.6, 399.8, 10.7, 400.3, 10.5, 400.6);
    ctx.bezierCurveTo(10.2, 400.9, 9.8, 401.0, 9.4, 400.7);
    ctx.bezierCurveTo(9.1, 400.5, 9.0, 400.0, 9.3, 399.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(362.9, 252.2);
    ctx.bezierCurveTo(362.8, 252.2, 362.6, 252.1, 362.5, 251.9);
    ctx.lineTo(358.9, 246.0);
    ctx.lineTo(358.9, 246.0);
    ctx.bezierCurveTo(356.9, 246.8, 354.8, 247.1, 352.7, 246.7);
    ctx.bezierCurveTo(348.6, 246.0, 343.8, 242.6, 342.8, 237.3);
    ctx.bezierCurveTo(341.9, 232.6, 345.6, 229.8, 346.0, 229.5);
    ctx.bezierCurveTo(350.8, 226.2, 356.5, 226.0, 363.2, 229.0);
    ctx.bezierCurveTo(364.1, 229.4, 370.0, 233.4, 368.8, 238.9);
    ctx.bezierCurveTo(368.0, 242.6, 366.0, 243.5, 364.7, 244.1);
    ctx.bezierCurveTo(364.5, 244.2, 364.3, 244.3, 364.2, 244.4);
    ctx.bezierCurveTo(364.0, 244.5, 363.8, 244.7, 363.9, 244.9);
    ctx.lineTo(363.6, 251.7);
    ctx.bezierCurveTo(363.4, 252.0, 363.3, 252.2, 362.9, 252.2);
    ctx.lineTo(362.9, 252.2);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(359.4, 245.6);
    ctx.lineTo(362.8, 251.4);
    ctx.lineTo(363.1, 244.8);
    ctx.bezierCurveTo(363.1, 244.4, 363.4, 244.0, 363.8, 243.8);
    ctx.lineTo(364.4, 243.6);
    ctx.bezierCurveTo(365.6, 243.0, 367.4, 242.2, 368.1, 238.8);
    ctx.bezierCurveTo(369.2, 233.8, 363.8, 230.0, 362.9, 229.7);
    ctx.bezierCurveTo(356.4, 226.8, 350.8, 227.0, 346.2, 230.1);
    ctx.bezierCurveTo(344.0, 231.7, 342.9, 234.4, 343.3, 237.1);
    ctx.bezierCurveTo(344.3, 241.8, 348.1, 245.3, 352.7, 246.1);
    ctx.bezierCurveTo(354.7, 246.4, 356.7, 246.2, 358.6, 245.4);
    ctx.bezierCurveTo(358.9, 245.3, 359.2, 245.4, 359.4, 245.6);
    ctx.lineTo(359.4, 245.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(362.1, 237.5);
    ctx.bezierCurveTo(362.5, 237.2, 363.0, 237.2, 363.4, 237.5);
    ctx.bezierCurveTo(363.8, 237.9, 363.8, 238.5, 363.4, 238.8);
    ctx.bezierCurveTo(363.1, 239.2, 362.5, 239.2, 362.1, 238.8);
    ctx.bezierCurveTo(361.8, 238.4, 361.8, 237.9, 362.1, 237.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(355.1, 237.2);
    ctx.bezierCurveTo(355.5, 236.8, 356.1, 236.9, 356.4, 237.2);
    ctx.bezierCurveTo(356.8, 237.6, 356.8, 238.2, 356.4, 238.5);
    ctx.bezierCurveTo(356.1, 238.9, 355.5, 238.8, 355.2, 238.5);
    ctx.bezierCurveTo(354.8, 238.1, 354.8, 237.5, 355.1, 237.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(348.7, 236.5);
    ctx.bezierCurveTo(349.1, 236.2, 349.7, 236.2, 350.0, 236.6);
    ctx.bezierCurveTo(350.4, 236.9, 350.4, 237.5, 350.0, 237.9);
    ctx.bezierCurveTo(349.7, 238.2, 349.1, 238.2, 348.7, 237.8);
    ctx.bezierCurveTo(348.4, 237.5, 348.4, 236.9, 348.7, 236.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(298.6, 239.6);
    ctx.bezierCurveTo(298.4, 239.6, 298.2, 239.5, 298.1, 239.3);
    ctx.lineTo(294.5, 233.4);
    ctx.lineTo(294.5, 233.4);
    ctx.bezierCurveTo(292.6, 234.2, 290.4, 234.4, 288.4, 234.1);
    ctx.bezierCurveTo(284.2, 233.4, 279.4, 229.9, 278.4, 224.6);
    ctx.bezierCurveTo(277.5, 220.0, 281.2, 217.2, 281.6, 216.9);
    ctx.bezierCurveTo(286.4, 213.6, 292.1, 213.4, 298.9, 216.4);
    ctx.bezierCurveTo(299.7, 216.8, 305.7, 220.8, 304.5, 226.3);
    ctx.bezierCurveTo(303.6, 230.0, 301.6, 230.9, 300.3, 231.5);
    ctx.bezierCurveTo(300.1, 231.5, 300.0, 231.6, 299.8, 231.7);
    ctx.bezierCurveTo(299.6, 231.8, 299.5, 232.1, 299.5, 232.3);
    ctx.lineTo(299.2, 239.1);
    ctx.bezierCurveTo(299.1, 239.4, 298.9, 239.6, 298.6, 239.6);
    ctx.lineTo(298.6, 239.6);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(295.0, 233.0);
    ctx.lineTo(298.4, 238.7);
    ctx.lineTo(298.7, 232.2);
    ctx.bezierCurveTo(298.7, 231.8, 299.0, 231.4, 299.4, 231.2);
    ctx.lineTo(300.0, 230.9);
    ctx.bezierCurveTo(301.2, 230.4, 303.0, 229.6, 303.8, 226.2);
    ctx.bezierCurveTo(304.9, 221.2, 299.4, 217.4, 298.5, 217.1);
    ctx.bezierCurveTo(292.0, 214.2, 286.4, 214.3, 281.8, 217.5);
    ctx.bezierCurveTo(279.6, 219.1, 278.5, 221.8, 278.9, 224.5);
    ctx.bezierCurveTo(279.9, 229.1, 283.7, 232.7, 288.3, 233.4);
    ctx.bezierCurveTo(290.3, 233.8, 292.3, 233.5, 294.2, 232.7);
    ctx.bezierCurveTo(294.5, 232.7, 294.8, 232.8, 295.0, 233.0);
    ctx.lineTo(295.0, 233.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(297.7, 224.8);
    ctx.bezierCurveTo(298.1, 224.5, 298.7, 224.5, 299.0, 224.9);
    ctx.bezierCurveTo(299.4, 225.2, 299.4, 225.8, 299.0, 226.2);
    ctx.bezierCurveTo(298.7, 226.5, 298.1, 226.5, 297.8, 226.1);
    ctx.bezierCurveTo(297.4, 225.8, 297.4, 225.2, 297.7, 224.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(290.8, 224.5);
    ctx.bezierCurveTo(291.1, 224.2, 291.7, 224.2, 292.1, 224.5);
    ctx.bezierCurveTo(292.4, 224.9, 292.4, 225.5, 292.1, 225.8);
    ctx.bezierCurveTo(291.7, 226.2, 291.1, 226.2, 290.8, 225.8);
    ctx.bezierCurveTo(290.4, 225.4, 290.4, 224.9, 290.8, 224.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(284.4, 223.9);
    ctx.bezierCurveTo(284.7, 223.5, 285.3, 223.5, 285.7, 223.9);
    ctx.bezierCurveTo(286.0, 224.3, 286.0, 224.9, 285.7, 225.2);
    ctx.bezierCurveTo(285.3, 225.5, 284.7, 225.5, 284.4, 225.2);
    ctx.bezierCurveTo(284.0, 224.8, 284.0, 224.2, 284.4, 223.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(254.6, 407.6);
    ctx.bezierCurveTo(254.5, 407.6, 254.3, 407.5, 254.2, 407.3);
    ctx.lineTo(250.6, 401.4);
    ctx.lineTo(250.6, 401.4);
    ctx.bezierCurveTo(248.6, 402.2, 246.5, 402.4, 244.4, 402.1);
    ctx.bezierCurveTo(240.2, 401.4, 235.5, 397.9, 234.5, 392.7);
    ctx.bezierCurveTo(233.6, 388.0, 237.2, 385.2, 237.7, 384.9);
    ctx.bezierCurveTo(242.4, 381.6, 248.2, 381.4, 254.9, 384.4);
    ctx.bezierCurveTo(255.8, 384.8, 261.8, 388.8, 260.5, 394.3);
    ctx.bezierCurveTo(259.7, 398.0, 257.7, 398.9, 256.4, 399.5);
    ctx.bezierCurveTo(256.2, 399.5, 256.0, 399.6, 255.9, 399.8);
    ctx.bezierCurveTo(255.7, 399.9, 255.5, 400.1, 255.6, 400.3);
    ctx.lineTo(255.3, 407.1);
    ctx.bezierCurveTo(255.1, 407.4, 254.9, 407.6, 254.6, 407.6);
    ctx.lineTo(254.6, 407.6);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(251.1, 401.0);
    ctx.lineTo(254.5, 406.7);
    ctx.lineTo(254.8, 400.2);
    ctx.bezierCurveTo(254.8, 399.8, 255.1, 399.4, 255.5, 399.2);
    ctx.lineTo(256.0, 399.0);
    ctx.bezierCurveTo(257.3, 398.4, 259.1, 397.6, 259.8, 394.2);
    ctx.bezierCurveTo(260.9, 389.2, 255.5, 385.4, 254.6, 385.1);
    ctx.bezierCurveTo(248.1, 382.2, 242.5, 382.3, 237.9, 385.5);
    ctx.bezierCurveTo(235.7, 387.1, 234.6, 389.8, 235.0, 392.5);
    ctx.bezierCurveTo(236.0, 397.1, 239.8, 400.7, 244.4, 401.5);
    ctx.bezierCurveTo(246.4, 401.8, 248.4, 401.5, 250.3, 400.7);
    ctx.bezierCurveTo(250.6, 400.7, 250.9, 400.8, 251.1, 401.0);
    ctx.lineTo(251.1, 401.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(253.8, 392.8);
    ctx.bezierCurveTo(254.2, 392.5, 254.7, 392.5, 255.1, 392.9);
    ctx.bezierCurveTo(255.5, 393.2, 255.5, 393.8, 255.1, 394.2);
    ctx.bezierCurveTo(254.8, 394.5, 254.2, 394.5, 253.8, 394.1);
    ctx.bezierCurveTo(253.5, 393.8, 253.5, 393.2, 253.8, 392.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(246.8, 392.5);
    ctx.bezierCurveTo(247.2, 392.2, 247.8, 392.2, 248.1, 392.6);
    ctx.bezierCurveTo(248.5, 392.9, 248.5, 393.5, 248.1, 393.9);
    ctx.bezierCurveTo(247.8, 394.2, 247.2, 394.2, 246.8, 393.8);
    ctx.bezierCurveTo(246.5, 393.5, 246.5, 392.9, 246.8, 392.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(240.4, 391.9);
    ctx.bezierCurveTo(240.8, 391.5, 241.4, 391.5, 241.7, 391.9);
    ctx.bezierCurveTo(242.1, 392.3, 242.1, 392.9, 241.7, 393.2);
    ctx.bezierCurveTo(241.4, 393.6, 240.8, 393.5, 240.4, 393.2);
    ctx.bezierCurveTo(240.1, 392.8, 240.1, 392.2, 240.4, 391.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(401.9, 350.3);
    ctx.bezierCurveTo(401.7, 350.3, 401.5, 350.2, 401.4, 350.1);
    ctx.lineTo(397.8, 344.1);
    ctx.lineTo(397.8, 344.1);
    ctx.bezierCurveTo(395.9, 344.9, 393.7, 345.2, 391.6, 344.8);
    ctx.bezierCurveTo(387.5, 344.1, 382.7, 340.7, 381.7, 335.4);
    ctx.bezierCurveTo(381.2, 332.4, 382.4, 329.4, 384.9, 327.6);
    ctx.bezierCurveTo(389.7, 324.3, 395.4, 324.1, 402.2, 327.1);
    ctx.bezierCurveTo(403.0, 327.5, 409.0, 331.5, 407.8, 337.0);
    ctx.bezierCurveTo(406.9, 340.7, 404.9, 341.6, 403.6, 342.2);
    ctx.bezierCurveTo(403.4, 342.3, 403.2, 342.4, 403.1, 342.5);
    ctx.bezierCurveTo(402.9, 342.6, 402.8, 342.8, 402.8, 343.0);
    ctx.lineTo(402.5, 349.8);
    ctx.bezierCurveTo(402.4, 350.1, 402.2, 350.3, 401.9, 350.3);
    ctx.lineTo(401.9, 350.3);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(398.3, 343.7);
    ctx.lineTo(401.8, 349.5);
    ctx.lineTo(402.1, 342.9);
    ctx.bezierCurveTo(402.1, 342.5, 402.3, 342.1, 402.7, 341.9);
    ctx.lineTo(403.3, 341.7);
    ctx.bezierCurveTo(404.6, 341.1, 406.3, 340.3, 407.1, 336.9);
    ctx.bezierCurveTo(408.2, 331.9, 402.7, 328.1, 401.9, 327.8);
    ctx.bezierCurveTo(395.3, 324.9, 389.7, 325.1, 385.1, 328.3);
    ctx.bezierCurveTo(382.9, 329.8, 381.8, 332.6, 382.2, 335.3);
    ctx.bezierCurveTo(383.3, 339.9, 387.0, 343.4, 391.6, 344.2);
    ctx.bezierCurveTo(393.6, 344.5, 395.7, 344.2, 397.5, 343.5);
    ctx.bezierCurveTo(397.8, 343.4, 398.1, 343.5, 398.3, 343.7);
    ctx.lineTo(398.3, 343.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(401.0, 335.6);
    ctx.bezierCurveTo(401.4, 335.2, 402.0, 335.2, 402.3, 335.6);
    ctx.bezierCurveTo(402.7, 336.0, 402.7, 336.5, 402.3, 336.9);
    ctx.bezierCurveTo(402.0, 337.2, 401.4, 337.2, 401.0, 336.9);
    ctx.bezierCurveTo(400.7, 336.5, 400.7, 335.9, 401.0, 335.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(394.1, 335.3);
    ctx.bezierCurveTo(394.4, 334.9, 395.0, 334.9, 395.4, 335.3);
    ctx.bezierCurveTo(395.7, 335.7, 395.7, 336.2, 395.4, 336.6);
    ctx.bezierCurveTo(395.0, 336.9, 394.4, 336.9, 394.1, 336.5);
    ctx.bezierCurveTo(393.7, 336.2, 393.7, 335.6, 394.1, 335.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(387.7, 334.6);
    ctx.bezierCurveTo(388.0, 334.3, 388.6, 334.3, 389.0, 334.6);
    ctx.bezierCurveTo(389.3, 335.0, 389.3, 335.6, 389.0, 335.9);
    ctx.bezierCurveTo(388.6, 336.3, 388.0, 336.3, 387.7, 335.9);
    ctx.bezierCurveTo(387.3, 335.5, 387.3, 335.0, 387.7, 334.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(343.4, 363.9);
    ctx.bezierCurveTo(343.2, 363.9, 343.1, 363.8, 343.0, 363.7);
    ctx.lineTo(339.4, 357.7);
    ctx.lineTo(339.4, 357.7);
    ctx.bezierCurveTo(337.4, 358.5, 335.3, 358.8, 333.2, 358.4);
    ctx.bezierCurveTo(329.0, 357.7, 324.2, 354.3, 323.3, 349.0);
    ctx.bezierCurveTo(322.3, 344.3, 326.0, 341.6, 326.5, 341.2);
    ctx.bezierCurveTo(331.2, 337.9, 337.0, 337.7, 343.7, 340.7);
    ctx.bezierCurveTo(344.6, 341.1, 350.5, 345.1, 349.3, 350.6);
    ctx.bezierCurveTo(348.4, 354.3, 346.5, 355.2, 345.1, 355.8);
    ctx.bezierCurveTo(345.0, 355.9, 344.8, 356.0, 344.6, 356.1);
    ctx.bezierCurveTo(344.4, 356.2, 344.3, 356.4, 344.3, 356.6);
    ctx.lineTo(344.0, 363.4);
    ctx.bezierCurveTo(343.9, 363.7, 343.7, 363.9, 343.4, 363.9);
    ctx.lineTo(343.4, 363.9);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(339.9, 357.3);
    ctx.lineTo(343.3, 363.1);
    ctx.lineTo(343.6, 356.5);
    ctx.bezierCurveTo(343.6, 356.1, 343.9, 355.7, 344.3, 355.5);
    ctx.lineTo(344.8, 355.3);
    ctx.bezierCurveTo(346.1, 354.7, 347.9, 353.9, 348.6, 350.5);
    ctx.bezierCurveTo(349.7, 345.5, 344.3, 341.7, 343.4, 341.4);
    ctx.bezierCurveTo(336.9, 338.5, 331.3, 338.7, 326.7, 341.9);
    ctx.bezierCurveTo(324.5, 343.4, 323.3, 346.2, 323.7, 348.9);
    ctx.bezierCurveTo(324.8, 353.5, 328.5, 357.0, 333.2, 357.8);
    ctx.bezierCurveTo(335.2, 358.1, 337.2, 357.8, 339.1, 357.1);
    ctx.bezierCurveTo(339.4, 357.0, 339.7, 357.1, 339.9, 357.3);
    ctx.lineTo(339.9, 357.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(342.6, 349.2);
    ctx.bezierCurveTo(342.9, 348.8, 343.5, 348.8, 343.9, 349.2);
    ctx.bezierCurveTo(344.2, 349.6, 344.2, 350.2, 343.9, 350.5);
    ctx.bezierCurveTo(343.5, 350.9, 342.9, 350.8, 342.6, 350.5);
    ctx.bezierCurveTo(342.2, 350.1, 342.2, 349.5, 342.6, 349.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(335.6, 348.9);
    ctx.bezierCurveTo(336.0, 348.5, 336.6, 348.5, 336.9, 348.9);
    ctx.bezierCurveTo(337.3, 349.3, 337.3, 349.8, 336.9, 350.2);
    ctx.bezierCurveTo(336.6, 350.5, 336.0, 350.5, 335.6, 350.1);
    ctx.bezierCurveTo(335.3, 349.8, 335.3, 349.2, 335.6, 348.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(329.2, 348.2);
    ctx.bezierCurveTo(329.6, 347.9, 330.1, 347.9, 330.5, 348.2);
    ctx.bezierCurveTo(330.9, 348.6, 330.9, 349.2, 330.5, 349.5);
    ctx.bezierCurveTo(330.2, 349.9, 329.6, 349.9, 329.2, 349.5);
    ctx.bezierCurveTo(328.9, 349.1, 328.9, 348.6, 329.2, 348.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(351.4, 140.4);
    ctx.bezierCurveTo(351.2, 140.4, 351.0, 140.3, 350.9, 140.1);
    ctx.lineTo(347.3, 134.2);
    ctx.lineTo(347.3, 134.2);
    ctx.bezierCurveTo(345.4, 135.0, 343.2, 135.2, 341.1, 134.9);
    ctx.bezierCurveTo(337.0, 134.2, 332.2, 130.7, 331.2, 125.5);
    ctx.bezierCurveTo(330.3, 120.8, 334.0, 118.0, 334.4, 117.7);
    ctx.bezierCurveTo(339.2, 114.4, 344.9, 114.2, 351.7, 117.2);
    ctx.bezierCurveTo(352.5, 117.6, 358.5, 121.6, 357.2, 127.1);
    ctx.bezierCurveTo(356.4, 130.8, 354.4, 131.7, 353.1, 132.3);
    ctx.bezierCurveTo(352.9, 132.4, 352.7, 132.5, 352.6, 132.6);
    ctx.bezierCurveTo(352.4, 132.7, 352.3, 132.9, 352.3, 133.1);
    ctx.lineTo(352.0, 139.9);
    ctx.bezierCurveTo(351.9, 140.2, 351.7, 140.4, 351.4, 140.4);
    ctx.lineTo(351.4, 140.4);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(347.8, 133.8);
    ctx.lineTo(351.2, 139.5);
    ctx.lineTo(351.6, 133.0);
    ctx.bezierCurveTo(351.6, 132.6, 351.8, 132.2, 352.2, 132.0);
    ctx.lineTo(352.8, 131.7);
    ctx.bezierCurveTo(354.1, 131.1, 355.9, 130.4, 356.6, 127.0);
    ctx.bezierCurveTo(357.7, 122.0, 352.2, 118.2, 351.4, 117.8);
    ctx.bezierCurveTo(344.8, 115.0, 339.2, 115.1, 334.6, 118.3);
    ctx.bezierCurveTo(332.4, 119.9, 331.3, 122.6, 331.7, 125.3);
    ctx.bezierCurveTo(332.8, 129.9, 336.5, 133.4, 341.1, 134.2);
    ctx.bezierCurveTo(343.1, 134.5, 345.2, 134.3, 347.0, 133.5);
    ctx.bezierCurveTo(347.3, 133.4, 347.6, 133.5, 347.8, 133.8);
    ctx.lineTo(347.8, 133.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(350.5, 125.6);
    ctx.bezierCurveTo(350.9, 125.3, 351.5, 125.3, 351.8, 125.7);
    ctx.bezierCurveTo(352.2, 126.0, 352.2, 126.6, 351.8, 126.9);
    ctx.bezierCurveTo(351.5, 127.3, 350.9, 127.3, 350.5, 126.9);
    ctx.bezierCurveTo(350.2, 126.5, 350.2, 126.0, 350.5, 125.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(343.6, 125.3);
    ctx.bezierCurveTo(343.9, 124.9, 344.5, 125.0, 344.9, 125.3);
    ctx.bezierCurveTo(345.2, 125.7, 345.2, 126.3, 344.9, 126.6);
    ctx.bezierCurveTo(344.5, 127.0, 343.9, 127.0, 343.6, 126.6);
    ctx.bezierCurveTo(343.2, 126.2, 343.2, 125.6, 343.6, 125.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(337.2, 124.7);
    ctx.bezierCurveTo(337.5, 124.3, 338.1, 124.3, 338.5, 124.7);
    ctx.bezierCurveTo(338.8, 125.1, 338.8, 125.6, 338.5, 126.0);
    ctx.bezierCurveTo(338.1, 126.3, 337.5, 126.3, 337.2, 125.9);
    ctx.bezierCurveTo(336.8, 125.6, 336.8, 125.0, 337.2, 124.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(363.6, 99.9);
    ctx.bezierCurveTo(363.5, 99.9, 363.3, 99.8, 363.2, 99.6);
    ctx.lineTo(360.0, 93.9);
    ctx.lineTo(360.0, 93.9);
    ctx.bezierCurveTo(358.2, 94.7, 356.3, 94.9, 354.3, 94.6);
    ctx.bezierCurveTo(349.7, 93.7, 346.2, 90.0, 345.3, 85.4);
    ctx.bezierCurveTo(344.8, 82.6, 345.9, 79.7, 348.2, 77.9);
    ctx.bezierCurveTo(352.5, 74.7, 357.8, 74.5, 364.0, 77.4);
    ctx.bezierCurveTo(364.8, 77.8, 370.2, 81.7, 369.1, 87.0);
    ctx.bezierCurveTo(368.3, 90.6, 366.5, 91.5, 365.3, 92.0);
    ctx.bezierCurveTo(365.1, 92.1, 364.9, 92.2, 364.8, 92.3);
    ctx.bezierCurveTo(364.6, 92.4, 364.5, 92.6, 364.5, 92.8);
    ctx.lineTo(364.3, 99.3);
    ctx.bezierCurveTo(364.1, 99.7, 364.0, 99.8, 363.7, 99.8);
    ctx.lineTo(363.6, 99.9);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(360.4, 93.5);
    ctx.lineTo(363.5, 99.1);
    ctx.lineTo(363.8, 92.8);
    ctx.bezierCurveTo(363.8, 92.3, 364.0, 92.0, 364.4, 91.8);
    ctx.lineTo(364.9, 91.5);
    ctx.bezierCurveTo(366.1, 90.9, 367.7, 90.2, 368.4, 86.9);
    ctx.bezierCurveTo(369.4, 82.0, 364.4, 78.4, 363.6, 78.1);
    ctx.bezierCurveTo(357.6, 75.3, 352.6, 75.4, 348.4, 78.5);
    ctx.bezierCurveTo(346.3, 80.1, 345.2, 82.7, 345.7, 85.3);
    ctx.bezierCurveTo(346.5, 89.7, 349.9, 93.1, 354.3, 94.0);
    ctx.bezierCurveTo(356.1, 94.3, 358.0, 94.0, 359.7, 93.3);
    ctx.bezierCurveTo(359.9, 93.2, 360.2, 93.3, 360.4, 93.5);
    ctx.lineTo(360.4, 93.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(363.3, 85.4);
    ctx.bezierCurveTo(363.7, 85.3, 364.2, 85.6, 364.3, 86.1);
    ctx.bezierCurveTo(364.4, 86.6, 364.1, 87.1, 363.7, 87.2);
    ctx.bezierCurveTo(363.2, 87.3, 362.8, 87.0, 362.7, 86.5);
    ctx.bezierCurveTo(362.6, 86.0, 362.8, 85.6, 363.3, 85.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(356.9, 85.1);
    ctx.bezierCurveTo(357.3, 85.0, 357.8, 85.3, 357.9, 85.7);
    ctx.bezierCurveTo(358.0, 86.2, 357.8, 86.7, 357.3, 86.8);
    ctx.bezierCurveTo(356.9, 86.9, 356.4, 86.6, 356.3, 86.1);
    ctx.bezierCurveTo(356.2, 85.7, 356.5, 85.2, 356.9, 85.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(351.0, 84.4);
    ctx.bezierCurveTo(351.5, 84.3, 351.9, 84.6, 352.1, 85.1);
    ctx.bezierCurveTo(352.2, 85.6, 351.9, 86.1, 351.5, 86.2);
    ctx.bezierCurveTo(351.0, 86.3, 350.6, 86.0, 350.4, 85.5);
    ctx.bezierCurveTo(350.3, 85.0, 350.6, 84.5, 351.0, 84.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.restore();
    ctx.beginPath();
    ctx.moveTo(391.7, 0.2);
    ctx.lineTo(390.9, 0.2);
    ctx.bezierCurveTo(392.4, 1.8, 394.1, 4.4, 393.5, 7.4);
    ctx.bezierCurveTo(392.8, 10.7, 391.2, 11.4, 390.0, 12.0);
    ctx.lineTo(389.5, 12.3);
    ctx.bezierCurveTo(389.2, 12.5, 388.9, 12.8, 388.9, 13.3);
    ctx.lineTo(388.6, 19.6);
    ctx.lineTo(385.5, 14.0);
    ctx.bezierCurveTo(385.3, 13.8, 385.1, 13.7, 384.8, 13.8);
    ctx.bezierCurveTo(383.1, 14.5, 381.2, 14.8, 379.4, 14.5);
    ctx.bezierCurveTo(375.1, 13.6, 371.7, 10.2, 370.8, 5.8);
    ctx.bezierCurveTo(370.4, 3.8, 371.0, 1.8, 372.3, 0.2);
    ctx.lineTo(371.6, 0.2);
    ctx.bezierCurveTo(370.4, 1.9, 369.9, 4.0, 370.3, 6.0);
    ctx.bezierCurveTo(371.2, 10.6, 374.8, 14.2, 379.4, 15.1);
    ctx.bezierCurveTo(379.9, 15.2, 380.5, 15.2, 381.0, 15.2);
    ctx.bezierCurveTo(382.4, 15.2, 383.8, 14.9, 385.0, 14.4);
    ctx.lineTo(388.3, 20.1);
    ctx.bezierCurveTo(388.4, 20.3, 388.6, 20.4, 388.7, 20.4);
    ctx.bezierCurveTo(389.0, 20.4, 389.2, 20.2, 389.3, 19.9);
    ctx.lineTo(389.6, 13.3);
    ctx.bezierCurveTo(389.6, 13.1, 389.7, 12.9, 389.9, 12.8);
    ctx.bezierCurveTo(390.0, 12.7, 390.1, 12.6, 390.3, 12.5);
    ctx.bezierCurveTo(391.5, 12.0, 393.3, 11.1, 394.1, 7.5);
    ctx.bezierCurveTo(394.5, 4.8, 393.7, 2.1, 391.7, 0.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(388.4, 6.0);
    ctx.bezierCurveTo(388.8, 5.8, 389.3, 6.1, 389.4, 6.6);
    ctx.bezierCurveTo(389.5, 7.1, 389.2, 7.6, 388.8, 7.7);
    ctx.bezierCurveTo(388.4, 7.8, 387.9, 7.5, 387.8, 7.0);
    ctx.bezierCurveTo(387.7, 6.5, 387.9, 6.1, 388.4, 6.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(382.0, 5.6);
    ctx.bezierCurveTo(382.5, 5.5, 382.9, 5.8, 383.0, 6.2);
    ctx.bezierCurveTo(383.2, 6.7, 382.9, 7.2, 382.4, 7.3);
    ctx.bezierCurveTo(382.0, 7.4, 381.5, 7.1, 381.4, 6.6);
    ctx.bezierCurveTo(381.3, 6.2, 381.6, 5.7, 382.0, 5.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(376.1, 5.0);
    ctx.bezierCurveTo(376.6, 4.8, 377.1, 5.1, 377.2, 5.6);
    ctx.bezierCurveTo(377.3, 6.1, 377.0, 6.6, 376.6, 6.7);
    ctx.bezierCurveTo(376.1, 6.8, 375.7, 6.5, 375.6, 6.0);
    ctx.bezierCurveTo(375.4, 5.5, 375.7, 5.1, 376.1, 5.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(389.0, 411.9);
    ctx.bezierCurveTo(382.8, 409.0, 377.6, 409.2, 373.2, 412.4);
    ctx.bezierCurveTo(372.6, 413.0, 372.1, 413.5, 371.6, 414.2);
    ctx.lineTo(372.3, 414.2);
    ctx.bezierCurveTo(372.6, 413.8, 373.0, 413.4, 373.5, 413.0);
    ctx.bezierCurveTo(377.7, 409.9, 382.8, 409.8, 388.8, 412.6);
    ctx.bezierCurveTo(389.5, 413.0, 390.3, 413.6, 390.9, 414.2);
    ctx.lineTo(391.7, 414.2);
    ctx.bezierCurveTo(391.0, 413.3, 390.0, 412.5, 389.0, 411.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(324.0, 160.3);
    ctx.bezierCurveTo(323.8, 160.3, 323.6, 160.2, 323.5, 160.0);
    ctx.lineTo(319.0, 152.2);
    ctx.lineTo(319.0, 152.2);
    ctx.bezierCurveTo(316.6, 153.2, 314.0, 153.5, 311.4, 153.1);
    ctx.bezierCurveTo(305.2, 151.9, 300.4, 147.0, 299.2, 140.8);
    ctx.bezierCurveTo(298.6, 137.0, 300.1, 133.1, 303.1, 130.8);
    ctx.bezierCurveTo(309.0, 126.4, 316.1, 126.2, 324.3, 130.1);
    ctx.bezierCurveTo(325.3, 130.6, 332.7, 135.8, 331.2, 143.0);
    ctx.bezierCurveTo(330.1, 147.8, 327.7, 149.0, 326.1, 149.7);
    ctx.bezierCurveTo(325.8, 149.8, 325.6, 149.9, 325.5, 150.1);
    ctx.bezierCurveTo(325.2, 150.2, 325.1, 150.5, 325.1, 150.8);
    ctx.lineTo(324.7, 159.6);
    ctx.bezierCurveTo(324.6, 160.0, 324.3, 160.3, 324.0, 160.3);
    ctx.lineTo(324.0, 160.3);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(319.6, 151.7);
    ctx.lineTo(323.9, 159.2);
    ctx.lineTo(324.2, 150.7);
    ctx.bezierCurveTo(324.2, 150.1, 324.5, 149.6, 325.0, 149.4);
    ctx.lineTo(325.7, 149.0);
    ctx.bezierCurveTo(327.3, 148.3, 329.5, 147.2, 330.4, 142.8);
    ctx.bezierCurveTo(331.7, 136.3, 325.0, 131.4, 324.0, 131.0);
    ctx.bezierCurveTo(316.0, 127.2, 309.1, 127.4, 303.5, 131.6);
    ctx.bezierCurveTo(300.7, 133.7, 299.3, 137.2, 299.9, 140.7);
    ctx.bezierCurveTo(301.0, 146.6, 305.6, 151.2, 311.4, 152.3);
    ctx.bezierCurveTo(313.9, 152.7, 316.4, 152.4, 318.7, 151.4);
    ctx.bezierCurveTo(319.0, 151.3, 319.4, 151.4, 319.7, 151.7);
    ctx.lineTo(319.6, 151.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(323.5, 140.9);
    ctx.bezierCurveTo(324.1, 140.7, 324.7, 141.1, 324.8, 141.8);
    ctx.bezierCurveTo(325.0, 142.4, 324.6, 143.1, 324.0, 143.2);
    ctx.bezierCurveTo(323.4, 143.4, 322.8, 143.0, 322.7, 142.3);
    ctx.bezierCurveTo(322.5, 141.7, 322.9, 141.0, 323.5, 140.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(314.9, 140.4);
    ctx.bezierCurveTo(315.5, 140.2, 316.1, 140.6, 316.3, 141.3);
    ctx.bezierCurveTo(316.4, 141.9, 316.1, 142.6, 315.5, 142.7);
    ctx.bezierCurveTo(314.9, 142.9, 314.3, 142.5, 314.1, 141.8);
    ctx.bezierCurveTo(314.0, 141.2, 314.3, 140.5, 314.9, 140.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(307.0, 139.6);
    ctx.bezierCurveTo(307.6, 139.4, 308.3, 139.8, 308.4, 140.4);
    ctx.bezierCurveTo(308.6, 141.1, 308.2, 141.7, 307.6, 141.9);
    ctx.bezierCurveTo(307.0, 142.0, 306.4, 141.6, 306.2, 141.0);
    ctx.bezierCurveTo(306.1, 140.3, 306.4, 139.7, 307.0, 139.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(260.7, 186.2);
    ctx.bezierCurveTo(260.5, 186.2, 260.3, 186.1, 260.2, 185.9);
    ctx.lineTo(256.2, 179.0);
    ctx.lineTo(256.2, 179.0);
    ctx.bezierCurveTo(254.1, 179.9, 251.7, 180.2, 249.4, 179.8);
    ctx.bezierCurveTo(243.9, 178.7, 239.6, 174.3, 238.5, 168.8);
    ctx.bezierCurveTo(237.9, 165.4, 239.2, 161.9, 242.0, 159.7);
    ctx.bezierCurveTo(247.2, 155.9, 253.6, 155.6, 261.0, 159.1);
    ctx.bezierCurveTo(262.0, 159.6, 268.5, 164.3, 267.2, 170.7);
    ctx.bezierCurveTo(266.2, 175.1, 264.1, 176.1, 262.6, 176.8);
    ctx.bezierCurveTo(262.4, 176.9, 262.2, 177.0, 262.0, 177.1);
    ctx.bezierCurveTo(261.8, 177.2, 261.7, 177.5, 261.7, 177.7);
    ctx.lineTo(261.4, 185.6);
    ctx.bezierCurveTo(261.2, 186.0, 261.0, 186.3, 260.7, 186.3);
    ctx.lineTo(260.7, 186.2);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(256.8, 178.5);
    ctx.lineTo(260.6, 185.2);
    ctx.lineTo(260.9, 177.6);
    ctx.bezierCurveTo(260.9, 177.1, 261.2, 176.6, 261.6, 176.4);
    ctx.lineTo(262.3, 176.1);
    ctx.bezierCurveTo(263.7, 175.4, 265.6, 174.5, 266.4, 170.5);
    ctx.bezierCurveTo(267.7, 164.6, 261.6, 160.2, 260.7, 159.8);
    ctx.bezierCurveTo(253.5, 156.5, 247.3, 156.6, 242.3, 160.4);
    ctx.bezierCurveTo(239.7, 162.3, 238.5, 165.5, 239.0, 168.6);
    ctx.bezierCurveTo(240.1, 173.9, 244.2, 178.0, 249.4, 179.0);
    ctx.bezierCurveTo(251.6, 179.4, 253.9, 179.1, 255.9, 178.2);
    ctx.bezierCurveTo(256.2, 178.1, 256.6, 178.3, 256.8, 178.5);
    ctx.lineTo(256.8, 178.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(260.2, 168.7);
    ctx.bezierCurveTo(260.8, 168.6, 261.3, 169.0, 261.5, 169.5);
    ctx.bezierCurveTo(261.6, 170.1, 261.3, 170.7, 260.8, 170.8);
    ctx.bezierCurveTo(260.2, 170.9, 259.7, 170.6, 259.5, 170.0);
    ctx.bezierCurveTo(259.4, 169.4, 259.7, 168.9, 260.2, 168.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(252.6, 168.3);
    ctx.bezierCurveTo(253.1, 168.1, 253.7, 168.5, 253.8, 169.1);
    ctx.bezierCurveTo(253.9, 169.7, 253.6, 170.2, 253.1, 170.4);
    ctx.bezierCurveTo(252.5, 170.5, 252.0, 170.1, 251.8, 169.6);
    ctx.bezierCurveTo(251.7, 169.0, 252.0, 168.4, 252.6, 168.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(245.5, 167.5);
    ctx.bezierCurveTo(246.0, 167.4, 246.6, 167.8, 246.7, 168.3);
    ctx.bezierCurveTo(246.9, 168.9, 246.6, 169.5, 246.0, 169.6);
    ctx.bezierCurveTo(245.5, 169.7, 244.9, 169.4, 244.8, 168.8);
    ctx.bezierCurveTo(244.6, 168.2, 245.0, 167.7, 245.5, 167.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.restore();
    ctx.beginPath();
    ctx.moveTo(91.8, 0.2);
    ctx.lineTo(90.8, 0.2);
    ctx.bezierCurveTo(92.4, 2.2, 93.1, 4.7, 92.6, 7.2);
    ctx.bezierCurveTo(91.8, 11.2, 89.8, 12.1, 88.4, 12.8);
    ctx.lineTo(87.8, 13.1);
    ctx.bezierCurveTo(87.4, 13.3, 87.1, 13.8, 87.1, 14.3);
    ctx.lineTo(86.7, 21.9);
    ctx.lineTo(83.0, 15.2);
    ctx.bezierCurveTo(82.8, 15.0, 82.4, 14.8, 82.1, 14.9);
    ctx.bezierCurveTo(80.1, 15.8, 77.8, 16.1, 75.6, 15.7);
    ctx.bezierCurveTo(70.4, 14.7, 66.2, 10.6, 65.2, 5.3);
    ctx.bezierCurveTo(64.9, 3.6, 65.1, 1.8, 65.9, 0.2);
    ctx.lineTo(65.2, 0.2);
    ctx.bezierCurveTo(64.5, 1.9, 64.3, 3.7, 64.7, 5.4);
    ctx.bezierCurveTo(65.7, 11.0, 70.1, 15.4, 75.6, 16.5);
    ctx.bezierCurveTo(76.3, 16.6, 76.9, 16.7, 77.6, 16.6);
    ctx.bezierCurveTo(79.3, 16.6, 80.9, 16.3, 82.5, 15.6);
    ctx.lineTo(86.5, 22.6);
    ctx.bezierCurveTo(86.6, 22.8, 86.7, 22.9, 86.9, 22.9);
    ctx.bezierCurveTo(87.3, 22.9, 87.5, 22.7, 87.6, 22.3);
    ctx.lineTo(87.9, 14.4);
    ctx.bezierCurveTo(87.9, 14.1, 88.1, 13.9, 88.3, 13.7);
    ctx.bezierCurveTo(88.4, 13.6, 88.6, 13.5, 88.8, 13.4);
    ctx.bezierCurveTo(90.3, 12.8, 92.5, 11.7, 93.4, 7.3);
    ctx.bezierCurveTo(93.9, 4.8, 93.3, 2.3, 91.8, 0.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(86.4, 5.4);
    ctx.bezierCurveTo(87.0, 5.3, 87.5, 5.7, 87.7, 6.2);
    ctx.bezierCurveTo(87.8, 6.8, 87.5, 7.4, 86.9, 7.5);
    ctx.bezierCurveTo(86.4, 7.7, 85.8, 7.3, 85.7, 6.7);
    ctx.bezierCurveTo(85.6, 6.1, 85.9, 5.6, 86.4, 5.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(78.7, 5.0);
    ctx.bezierCurveTo(79.3, 4.9, 79.8, 5.2, 80.0, 5.8);
    ctx.bezierCurveTo(80.1, 6.4, 79.8, 6.9, 79.2, 7.1);
    ctx.bezierCurveTo(78.7, 7.2, 78.1, 6.9, 78.0, 6.3);
    ctx.bezierCurveTo(77.9, 5.7, 78.2, 5.1, 78.7, 5.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(71.7, 4.3);
    ctx.bezierCurveTo(72.2, 4.1, 72.8, 4.5, 72.9, 5.0);
    ctx.bezierCurveTo(73.0, 5.6, 72.7, 6.2, 72.2, 6.3);
    ctx.bezierCurveTo(71.6, 6.5, 71.1, 6.1, 70.9, 5.5);
    ctx.bezierCurveTo(70.8, 5.0, 71.1, 4.4, 71.7, 4.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(87.2, 409.8);
    ctx.bezierCurveTo(79.8, 406.3, 73.5, 406.5, 68.2, 410.4);
    ctx.bezierCurveTo(66.9, 411.4, 65.9, 412.7, 65.2, 414.2);
    ctx.lineTo(65.9, 414.2);
    ctx.bezierCurveTo(66.5, 413.0, 67.4, 411.9, 68.4, 411.1);
    ctx.bezierCurveTo(73.5, 407.3, 79.6, 407.2, 86.9, 410.5);
    ctx.bezierCurveTo(88.5, 411.5, 89.8, 412.7, 90.9, 414.2);
    ctx.lineTo(91.8, 414.2);
    ctx.bezierCurveTo(90.6, 412.4, 89.0, 410.9, 87.2, 409.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(117.6, 69.9);
    ctx.bezierCurveTo(117.4, 69.9, 117.3, 69.8, 117.2, 69.6);
    ctx.lineTo(113.9, 63.9);
    ctx.lineTo(113.9, 63.9);
    ctx.bezierCurveTo(112.1, 64.6, 110.1, 64.9, 108.2, 64.6);
    ctx.bezierCurveTo(103.6, 63.6, 100.1, 60.0, 99.2, 55.4);
    ctx.bezierCurveTo(98.7, 52.6, 99.8, 49.7, 102.1, 47.9);
    ctx.bezierCurveTo(106.4, 44.7, 111.7, 44.5, 117.9, 47.4);
    ctx.bezierCurveTo(118.7, 47.8, 124.1, 51.7, 123.0, 57.0);
    ctx.bezierCurveTo(122.2, 60.6, 120.4, 61.5, 119.2, 62.0);
    ctx.bezierCurveTo(119.0, 62.1, 118.8, 62.2, 118.7, 62.3);
    ctx.bezierCurveTo(118.5, 62.4, 118.4, 62.6, 118.4, 62.8);
    ctx.lineTo(118.2, 69.4);
    ctx.bezierCurveTo(118.0, 69.7, 117.9, 69.9, 117.6, 69.9);
    ctx.lineTo(117.6, 69.9);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(114.3, 63.5);
    ctx.lineTo(117.5, 69.1);
    ctx.lineTo(117.7, 62.7);
    ctx.bezierCurveTo(117.7, 62.3, 118.0, 61.9, 118.4, 61.7);
    ctx.lineTo(118.9, 61.5);
    ctx.bezierCurveTo(120.0, 60.9, 121.7, 60.2, 122.3, 56.9);
    ctx.bezierCurveTo(123.3, 52.0, 118.3, 48.3, 117.6, 48.0);
    ctx.bezierCurveTo(111.6, 45.3, 106.5, 45.4, 102.3, 48.5);
    ctx.bezierCurveTo(100.2, 50.1, 99.2, 52.7, 99.6, 55.3);
    ctx.bezierCurveTo(100.5, 59.7, 103.9, 63.1, 108.2, 63.9);
    ctx.bezierCurveTo(110.1, 64.3, 111.9, 64.0, 113.6, 63.3);
    ctx.bezierCurveTo(113.9, 63.2, 114.2, 63.3, 114.3, 63.5);
    ctx.lineTo(114.3, 63.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(117.2, 55.4);
    ctx.bezierCurveTo(117.7, 55.3, 118.1, 55.6, 118.2, 56.1);
    ctx.bezierCurveTo(118.3, 56.5, 118.1, 57.0, 117.6, 57.1);
    ctx.bezierCurveTo(117.2, 57.2, 116.7, 56.9, 116.6, 56.5);
    ctx.bezierCurveTo(116.5, 56.0, 116.8, 55.5, 117.2, 55.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(110.8, 55.0);
    ctx.bezierCurveTo(111.3, 54.9, 111.7, 55.2, 111.9, 55.7);
    ctx.bezierCurveTo(112.0, 56.2, 111.7, 56.7, 111.3, 56.8);
    ctx.bezierCurveTo(110.8, 56.9, 110.4, 56.6, 110.2, 56.1);
    ctx.bezierCurveTo(110.1, 55.6, 110.4, 55.2, 110.8, 55.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(105.0, 54.4);
    ctx.bezierCurveTo(105.4, 54.3, 105.9, 54.6, 106.0, 55.1);
    ctx.bezierCurveTo(106.1, 55.6, 105.9, 56.0, 105.4, 56.1);
    ctx.bezierCurveTo(105.0, 56.3, 104.5, 56.0, 104.4, 55.5);
    ctx.bezierCurveTo(104.3, 55.0, 104.5, 54.5, 105.0, 54.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(7.4, 103.2);
    ctx.bezierCurveTo(4.8, 102.0, 2.3, 101.3, 0.0, 101.2);
    ctx.lineTo(0.0, 101.9);
    ctx.bezierCurveTo(2.2, 102.1, 4.6, 102.7, 7.1, 103.9);
    ctx.bezierCurveTo(7.9, 104.2, 12.9, 107.9, 11.9, 112.7);
    ctx.bezierCurveTo(11.2, 116.0, 9.6, 116.8, 8.4, 117.3);
    ctx.lineTo(7.9, 117.6);
    ctx.bezierCurveTo(7.5, 117.8, 7.3, 118.2, 7.3, 118.6);
    ctx.lineTo(7.0, 124.9);
    ctx.lineTo(3.9, 119.4);
    ctx.bezierCurveTo(3.7, 119.1, 3.4, 119.0, 3.1, 119.1);
    ctx.bezierCurveTo(2.1, 119.5, 1.1, 119.8, 0.0, 119.9);
    ctx.lineTo(0.0, 120.5);
    ctx.bezierCurveTo(1.2, 120.5, 2.3, 120.2, 3.4, 119.7);
    ctx.lineTo(6.7, 125.5);
    ctx.bezierCurveTo(6.8, 125.6, 6.9, 125.7, 7.1, 125.7);
    ctx.bezierCurveTo(7.4, 125.7, 7.5, 125.5, 7.7, 125.2);
    ctx.lineTo(8.0, 118.6);
    ctx.bezierCurveTo(7.9, 118.4, 8.0, 118.2, 8.2, 118.1);
    ctx.bezierCurveTo(8.3, 118.0, 8.5, 117.9, 8.7, 117.9);
    ctx.bezierCurveTo(9.9, 117.3, 11.7, 116.4, 12.5, 112.8);
    ctx.bezierCurveTo(13.6, 107.5, 8.2, 103.6, 7.4, 103.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(6.7, 111.3);
    ctx.bezierCurveTo(7.2, 111.1, 7.6, 111.4, 7.7, 111.9);
    ctx.bezierCurveTo(7.9, 112.4, 7.6, 112.9, 7.2, 113.0);
    ctx.bezierCurveTo(6.7, 113.1, 6.3, 112.8, 6.1, 112.3);
    ctx.bezierCurveTo(6.0, 111.8, 6.3, 111.4, 6.7, 111.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(0.8, 112.6);
    ctx.bezierCurveTo(0.5, 112.7, 0.2, 112.6, 0.0, 112.4);
    ctx.lineTo(0.0, 111.1);
    ctx.bezierCurveTo(0.1, 111.0, 0.2, 110.9, 0.4, 110.9);
    ctx.bezierCurveTo(0.8, 110.8, 1.3, 111.1, 1.4, 111.6);
    ctx.bezierCurveTo(1.5, 112.0, 1.2, 112.5, 0.8, 112.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(405.8, 104.3);
    ctx.bezierCurveTo(408.6, 102.3, 411.7, 101.5, 415.2, 102.1);
    ctx.lineTo(415.2, 101.3);
    ctx.bezierCurveTo(411.6, 100.8, 408.4, 101.7, 405.6, 103.7);
    ctx.bezierCurveTo(403.3, 105.5, 402.2, 108.4, 402.7, 111.3);
    ctx.bezierCurveTo(403.6, 115.9, 407.2, 119.5, 411.8, 120.4);
    ctx.bezierCurveTo(412.3, 120.5, 412.9, 120.6, 413.4, 120.6);
    ctx.bezierCurveTo(414.0, 120.6, 414.6, 120.5, 415.2, 120.4);
    ctx.lineTo(415.2, 119.7);
    ctx.bezierCurveTo(414.1, 120.0, 412.9, 120.0, 411.8, 119.8);
    ctx.bezierCurveTo(407.4, 118.9, 404.0, 115.5, 403.1, 111.1);
    ctx.bezierCurveTo(402.7, 108.6, 403.7, 105.9, 405.8, 104.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(415.2, 111.2);
    ctx.lineTo(415.2, 112.4);
    ctx.bezierCurveTo(415.1, 112.5, 415.0, 112.6, 414.8, 112.6);
    ctx.bezierCurveTo(414.3, 112.7, 413.9, 112.4, 413.8, 112.0);
    ctx.bezierCurveTo(413.7, 111.5, 413.9, 111.0, 414.4, 110.9);
    ctx.bezierCurveTo(414.7, 110.8, 415.0, 110.9, 415.2, 111.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(408.5, 110.3);
    ctx.bezierCurveTo(408.9, 110.2, 409.4, 110.5, 409.5, 110.9);
    ctx.bezierCurveTo(409.6, 111.4, 409.4, 111.9, 408.9, 112.0);
    ctx.bezierCurveTo(408.5, 112.1, 408.0, 111.8, 407.9, 111.3);
    ctx.bezierCurveTo(407.8, 110.9, 408.1, 110.4, 408.5, 110.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(62.2, 116.6);
    ctx.bezierCurveTo(62.0, 116.6, 61.9, 116.5, 61.8, 116.4);
    ctx.lineTo(58.2, 110.3);
    ctx.lineTo(58.2, 110.3);
    ctx.bezierCurveTo(56.3, 111.1, 54.2, 111.3, 52.1, 111.0);
    ctx.bezierCurveTo(47.2, 110.1, 43.4, 106.2, 42.4, 101.3);
    ctx.bezierCurveTo(41.9, 98.3, 43.1, 95.3, 45.5, 93.4);
    ctx.bezierCurveTo(50.2, 90.0, 55.9, 89.8, 62.5, 92.9);
    ctx.bezierCurveTo(63.4, 93.3, 69.2, 97.4, 68.0, 103.0);
    ctx.bezierCurveTo(67.2, 106.8, 65.2, 107.7, 63.9, 108.3);
    ctx.bezierCurveTo(63.7, 108.4, 63.5, 108.5, 63.4, 108.6);
    ctx.bezierCurveTo(63.2, 108.7, 63.1, 108.9, 63.1, 109.1);
    ctx.lineTo(62.8, 116.1);
    ctx.bezierCurveTo(62.7, 116.5, 62.5, 116.7, 62.2, 116.7);
    ctx.lineTo(62.2, 116.6);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(58.7, 109.9);
    ctx.lineTo(62.1, 115.8);
    ctx.lineTo(62.4, 109.1);
    ctx.bezierCurveTo(62.4, 108.6, 62.6, 108.2, 63.0, 108.0);
    ctx.lineTo(63.6, 107.7);
    ctx.bezierCurveTo(64.9, 107.1, 66.6, 106.3, 67.3, 102.9);
    ctx.bezierCurveTo(68.4, 97.7, 63.1, 93.9, 62.2, 93.5);
    ctx.bezierCurveTo(55.8, 90.6, 50.3, 90.7, 45.8, 94.0);
    ctx.bezierCurveTo(43.5, 95.7, 42.4, 98.5, 42.8, 101.2);
    ctx.bezierCurveTo(43.8, 105.9, 47.5, 109.5, 52.1, 110.3);
    ctx.bezierCurveTo(54.1, 110.7, 56.1, 110.4, 57.9, 109.6);
    ctx.bezierCurveTo(58.2, 109.6, 58.5, 109.7, 58.7, 109.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(61.7, 101.4);
    ctx.bezierCurveTo(62.2, 101.2, 62.7, 101.5, 62.9, 102.0);
    ctx.bezierCurveTo(63.0, 102.5, 62.8, 103.0, 62.3, 103.1);
    ctx.bezierCurveTo(61.8, 103.3, 61.3, 103.0, 61.2, 102.5);
    ctx.bezierCurveTo(61.0, 102.1, 61.2, 101.5, 61.7, 101.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(54.9, 101.0);
    ctx.bezierCurveTo(55.3, 100.8, 55.9, 101.1, 56.0, 101.6);
    ctx.bezierCurveTo(56.2, 102.1, 55.9, 102.6, 55.5, 102.8);
    ctx.bezierCurveTo(55.0, 102.9, 54.5, 102.6, 54.3, 102.2);
    ctx.bezierCurveTo(54.2, 101.7, 54.4, 101.1, 54.9, 101.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(48.6, 100.3);
    ctx.bezierCurveTo(49.0, 100.2, 49.5, 100.4, 49.7, 100.9);
    ctx.bezierCurveTo(49.9, 101.4, 49.6, 101.9, 49.2, 102.1);
    ctx.bezierCurveTo(48.7, 102.3, 48.2, 102.0, 48.0, 101.5);
    ctx.bezierCurveTo(47.8, 101.0, 48.1, 100.5, 48.6, 100.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(40.8, 87.6);
    ctx.bezierCurveTo(40.5, 87.5, 40.3, 87.4, 40.2, 87.2);
    ctx.lineTo(35.3, 78.8);
    ctx.lineTo(35.3, 78.8);
    ctx.bezierCurveTo(32.6, 79.9, 29.7, 80.3, 26.8, 79.8);
    ctx.bezierCurveTo(21.2, 78.8, 14.7, 73.9, 13.3, 66.5);
    ctx.bezierCurveTo(12.1, 59.8, 17.1, 56.0, 17.7, 55.5);
    ctx.bezierCurveTo(24.2, 50.8, 32.0, 50.5, 41.2, 54.7);
    ctx.bezierCurveTo(42.4, 55.3, 50.5, 61.0, 48.8, 68.7);
    ctx.bezierCurveTo(47.6, 74.0, 44.9, 75.3, 43.1, 76.2);
    ctx.bezierCurveTo(42.9, 76.3, 42.7, 76.4, 42.5, 76.6);
    ctx.bezierCurveTo(42.2, 76.7, 42.0, 77.0, 42.1, 77.3);
    ctx.lineTo(41.6, 86.9);
    ctx.bezierCurveTo(41.5, 87.3, 41.2, 87.6, 40.8, 87.6);
    ctx.lineTo(40.8, 87.6);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(35.9, 78.3);
    ctx.lineTo(40.6, 86.4);
    ctx.lineTo(41.0, 77.2);
    ctx.bezierCurveTo(41.0, 76.6, 41.4, 76.0, 41.9, 75.7);
    ctx.lineTo(42.7, 75.3);
    ctx.bezierCurveTo(44.4, 74.5, 46.9, 73.4, 47.9, 68.6);
    ctx.bezierCurveTo(49.4, 61.5, 41.9, 56.2, 40.8, 55.7);
    ctx.bezierCurveTo(31.8, 51.7, 24.3, 51.9, 18.0, 56.4);
    ctx.bezierCurveTo(14.9, 58.7, 13.4, 62.5, 14.0, 66.3);
    ctx.bezierCurveTo(15.3, 72.7, 20.4, 77.7, 26.8, 78.9);
    ctx.bezierCurveTo(29.6, 79.3, 32.3, 79.0, 34.8, 77.9);
    ctx.bezierCurveTo(35.2, 77.8, 35.7, 77.9, 35.9, 78.3);
    ctx.lineTo(35.9, 78.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(40.1, 66.5);
    ctx.bezierCurveTo(40.7, 66.3, 41.4, 66.6, 41.7, 67.3);
    ctx.bezierCurveTo(41.9, 68.0, 41.6, 68.7, 41.0, 68.9);
    ctx.bezierCurveTo(40.3, 69.2, 39.6, 68.8, 39.4, 68.1);
    ctx.bezierCurveTo(39.1, 67.5, 39.4, 66.7, 40.1, 66.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(30.4, 66.1);
    ctx.bezierCurveTo(31.1, 65.9, 31.8, 66.2, 32.0, 66.9);
    ctx.bezierCurveTo(32.3, 67.6, 32.0, 68.3, 31.3, 68.5);
    ctx.bezierCurveTo(30.7, 68.8, 29.9, 68.4, 29.7, 67.7);
    ctx.bezierCurveTo(29.5, 67.1, 29.8, 66.3, 30.4, 66.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(21.9, 65.1);
    ctx.bezierCurveTo(22.5, 64.8, 23.2, 65.2, 23.5, 65.9);
    ctx.bezierCurveTo(23.7, 66.5, 23.4, 67.3, 22.8, 67.5);
    ctx.bezierCurveTo(22.1, 67.7, 21.4, 67.4, 21.1, 66.7);
    ctx.bezierCurveTo(20.9, 66.0, 21.2, 65.3, 21.9, 65.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(389.7, 136.8);
    ctx.bezierCurveTo(389.5, 136.8, 389.3, 136.7, 389.2, 136.5);
    ctx.lineTo(384.6, 129.1);
    ctx.lineTo(384.6, 129.1);
    ctx.bezierCurveTo(382.1, 130.1, 379.4, 130.4, 376.8, 130.0);
    ctx.bezierCurveTo(371.5, 129.1, 365.4, 124.9, 364.2, 118.3);
    ctx.bezierCurveTo(363.0, 112.5, 367.7, 109.1, 368.2, 108.7);
    ctx.bezierCurveTo(374.2, 104.6, 381.5, 104.4, 390.1, 108.1);
    ctx.bezierCurveTo(391.2, 108.6, 398.7, 113.6, 397.2, 120.3);
    ctx.bezierCurveTo(396.1, 124.9, 393.6, 126.1, 391.9, 126.8);
    ctx.bezierCurveTo(391.6, 126.9, 391.4, 127.0, 391.2, 127.1);
    ctx.bezierCurveTo(391.0, 127.2, 390.8, 127.5, 390.9, 127.8);
    ctx.lineTo(390.5, 136.2);
    ctx.bezierCurveTo(390.3, 136.6, 390.1, 136.8, 389.7, 136.8);
    ctx.lineTo(389.7, 136.8);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(385.2, 128.7);
    ctx.lineTo(389.6, 135.8);
    ctx.lineTo(390.0, 127.7);
    ctx.bezierCurveTo(390.0, 127.1, 390.3, 126.6, 390.8, 126.4);
    ctx.lineTo(391.5, 126.1);
    ctx.bezierCurveTo(393.2, 125.3, 395.4, 124.4, 396.3, 120.2);
    ctx.bezierCurveTo(397.7, 114.0, 390.8, 109.3, 389.7, 108.9);
    ctx.bezierCurveTo(381.4, 105.3, 374.4, 105.5, 368.5, 109.5);
    ctx.bezierCurveTo(368.1, 109.8, 363.8, 112.8, 364.8, 118.2);
    ctx.bezierCurveTo(366.0, 124.4, 371.7, 128.4, 376.8, 129.2);
    ctx.bezierCurveTo(379.3, 129.6, 381.9, 129.3, 384.3, 128.3);
    ctx.bezierCurveTo(384.6, 128.2, 385.0, 128.4, 385.3, 128.7);
    ctx.lineTo(385.2, 128.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(388.5, 118.9);
    ctx.bezierCurveTo(388.7, 118.4, 389.4, 118.1, 390.0, 118.4);
    ctx.bezierCurveTo(390.6, 118.7, 390.8, 119.4, 390.6, 120.0);
    ctx.bezierCurveTo(390.3, 120.5, 389.6, 120.7, 389.0, 120.4);
    ctx.bezierCurveTo(388.4, 120.2, 388.2, 119.5, 388.5, 118.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(379.6, 118.4);
    ctx.bezierCurveTo(379.9, 117.9, 380.6, 117.7, 381.2, 117.9);
    ctx.bezierCurveTo(381.8, 118.2, 382.0, 118.9, 381.7, 119.5);
    ctx.bezierCurveTo(381.4, 120.0, 380.7, 120.3, 380.2, 120.0);
    ctx.bezierCurveTo(379.6, 119.7, 379.3, 119.0, 379.6, 118.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(371.5, 117.6);
    ctx.bezierCurveTo(371.8, 117.1, 372.5, 116.9, 373.0, 117.2);
    ctx.bezierCurveTo(373.6, 117.4, 373.9, 118.1, 373.6, 118.7);
    ctx.bezierCurveTo(373.3, 119.2, 372.6, 119.5, 372.0, 119.2);
    ctx.bezierCurveTo(371.5, 118.9, 371.2, 118.2, 371.5, 117.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(263.5, 385.1);
    ctx.bezierCurveTo(263.2, 385.1, 263.0, 385.0, 262.9, 384.8);
    ctx.lineTo(257.6, 376.4);
    ctx.lineTo(257.6, 376.4);
    ctx.bezierCurveTo(254.7, 377.5, 251.6, 377.9, 248.6, 377.4);
    ctx.bezierCurveTo(242.6, 376.4, 235.6, 371.5, 234.2, 364.1);
    ctx.bezierCurveTo(232.9, 357.5, 238.2, 353.6, 238.8, 353.2);
    ctx.bezierCurveTo(245.8, 348.5, 254.1, 348.2, 263.9, 352.4);
    ctx.bezierCurveTo(265.1, 353.0, 273.8, 358.7, 272.0, 366.4);
    ctx.bezierCurveTo(270.7, 371.7, 267.9, 372.9, 265.9, 373.8);
    ctx.bezierCurveTo(265.7, 373.8, 265.4, 374.0, 265.2, 374.1);
    ctx.bezierCurveTo(264.9, 374.3, 264.7, 374.6, 264.8, 374.9);
    ctx.lineTo(264.3, 384.4);
    ctx.bezierCurveTo(264.2, 384.9, 263.9, 385.2, 263.4, 385.2);
    ctx.lineTo(263.5, 385.1);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(258.3, 375.9);
    ctx.lineTo(263.3, 383.9);
    ctx.lineTo(263.8, 374.7);
    ctx.bezierCurveTo(263.8, 374.1, 264.2, 373.5, 264.8, 373.3);
    ctx.lineTo(265.6, 372.9);
    ctx.bezierCurveTo(267.4, 372.1, 270.0, 371.0, 271.1, 366.2);
    ctx.bezierCurveTo(272.7, 359.1, 264.8, 353.8, 263.5, 353.4);
    ctx.bezierCurveTo(254.0, 349.4, 245.9, 349.5, 239.3, 354.0);
    ctx.bezierCurveTo(238.7, 354.4, 233.8, 357.9, 235.0, 363.9);
    ctx.bezierCurveTo(236.4, 371.0, 242.9, 375.6, 248.7, 376.5);
    ctx.bezierCurveTo(251.6, 376.9, 254.5, 376.6, 257.2, 375.5);
    ctx.bezierCurveTo(257.6, 375.4, 258.1, 375.5, 258.4, 375.9);
    ctx.lineTo(258.3, 375.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(262.0, 364.8);
    ctx.bezierCurveTo(262.3, 364.2, 263.0, 363.9, 263.7, 364.2);
    ctx.bezierCurveTo(264.4, 364.5, 264.7, 365.3, 264.4, 365.9);
    ctx.bezierCurveTo(264.2, 366.6, 263.4, 366.8, 262.7, 366.5);
    ctx.bezierCurveTo(262.0, 366.3, 261.7, 365.5, 262.0, 364.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(251.9, 364.3);
    ctx.bezierCurveTo(252.1, 363.7, 252.9, 363.4, 253.6, 363.7);
    ctx.bezierCurveTo(254.3, 364.0, 254.6, 364.7, 254.3, 365.4);
    ctx.bezierCurveTo(254.1, 366.0, 253.3, 366.3, 252.6, 366.0);
    ctx.bezierCurveTo(251.9, 365.7, 251.6, 365.0, 251.9, 364.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(242.6, 363.4);
    ctx.bezierCurveTo(242.8, 362.8, 243.6, 362.5, 244.3, 362.8);
    ctx.bezierCurveTo(245.0, 363.1, 245.3, 363.8, 245.0, 364.5);
    ctx.bezierCurveTo(244.7, 365.1, 244.0, 365.4, 243.3, 365.1);
    ctx.bezierCurveTo(242.6, 364.8, 242.3, 364.1, 242.6, 363.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(139.0, 188.3);
    ctx.bezierCurveTo(138.7, 188.3, 138.5, 188.2, 138.4, 187.9);
    ctx.lineTo(133.3, 179.8);
    ctx.lineTo(133.3, 179.8);
    ctx.bezierCurveTo(130.5, 180.9, 127.5, 181.3, 124.6, 180.8);
    ctx.bezierCurveTo(118.7, 179.8, 112.0, 175.1, 110.6, 167.9);
    ctx.bezierCurveTo(109.3, 161.5, 114.5, 157.7, 115.1, 157.3);
    ctx.bezierCurveTo(121.8, 152.7, 129.9, 152.5, 139.4, 156.6);
    ctx.bezierCurveTo(140.6, 157.1, 149.0, 162.6, 147.3, 170.1);
    ctx.bezierCurveTo(146.1, 175.2, 143.3, 176.5, 141.4, 177.3);
    ctx.bezierCurveTo(141.2, 177.3, 140.9, 177.4, 140.7, 177.6);
    ctx.bezierCurveTo(140.4, 177.7, 140.3, 178.0, 140.3, 178.3);
    ctx.lineTo(139.9, 187.6);
    ctx.bezierCurveTo(139.7, 188.0, 139.4, 188.3, 139.0, 188.3);
    ctx.lineTo(139.0, 188.3);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(134.0, 179.3);
    ctx.lineTo(138.8, 187.1);
    ctx.lineTo(139.3, 178.2);
    ctx.bezierCurveTo(139.3, 177.6, 139.6, 177.0, 140.2, 176.8);
    ctx.lineTo(141.0, 176.4);
    ctx.bezierCurveTo(142.8, 175.6, 145.3, 174.6, 146.4, 169.9);
    ctx.bezierCurveTo(147.9, 163.1, 140.2, 157.9, 139.0, 157.4);
    ctx.bezierCurveTo(129.8, 153.5, 121.9, 153.7, 115.4, 158.1);
    ctx.bezierCurveTo(114.9, 158.4, 110.2, 161.8, 111.3, 167.7);
    ctx.bezierCurveTo(112.7, 174.6, 119.0, 179.0, 124.6, 179.9);
    ctx.bezierCurveTo(127.4, 180.4, 130.2, 180.0, 132.9, 178.9);
    ctx.bezierCurveTo(133.3, 178.8, 133.7, 179.0, 134.0, 179.3);
    ctx.lineTo(134.0, 179.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(137.5, 168.6);
    ctx.bezierCurveTo(137.8, 168.0, 138.6, 167.7, 139.2, 168.0);
    ctx.bezierCurveTo(139.9, 168.2, 140.2, 169.0, 139.9, 169.6);
    ctx.bezierCurveTo(139.7, 170.2, 138.9, 170.5, 138.3, 170.2);
    ctx.bezierCurveTo(137.6, 170.0, 137.3, 169.2, 137.5, 168.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(127.7, 168.1);
    ctx.bezierCurveTo(128.0, 167.4, 128.8, 167.2, 129.4, 167.4);
    ctx.bezierCurveTo(130.1, 167.7, 130.4, 168.5, 130.1, 169.1);
    ctx.bezierCurveTo(129.9, 169.7, 129.1, 170.0, 128.4, 169.7);
    ctx.bezierCurveTo(127.8, 169.4, 127.5, 168.7, 127.7, 168.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(118.7, 167.2);
    ctx.bezierCurveTo(119.0, 166.6, 119.7, 166.3, 120.4, 166.6);
    ctx.bezierCurveTo(121.0, 166.8, 121.4, 167.6, 121.1, 168.2);
    ctx.bezierCurveTo(120.8, 168.8, 120.1, 169.1, 119.4, 168.8);
    ctx.bezierCurveTo(118.7, 168.6, 118.4, 167.8, 118.7, 167.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(171.7, 0.2);
    ctx.bezierCurveTo(171.7, 0.8, 171.6, 1.4, 171.4, 2.1);
    ctx.bezierCurveTo(170.4, 6.7, 167.9, 7.8, 166.1, 8.6);
    ctx.lineTo(165.3, 9.0);
    ctx.bezierCurveTo(164.7, 9.2, 164.4, 9.8, 164.4, 10.4);
    ctx.lineTo(163.9, 19.3);
    ctx.lineTo(159.1, 11.5);
    ctx.lineTo(159.1, 11.4);
    ctx.bezierCurveTo(158.8, 11.1, 158.4, 11.0, 158.0, 11.1);
    ctx.bezierCurveTo(155.3, 12.2, 152.5, 12.5, 149.7, 12.1);
    ctx.bezierCurveTo(144.2, 11.2, 138.0, 6.9, 136.4, 0.2);
    ctx.lineTo(135.7, 0.2);
    ctx.bezierCurveTo(137.2, 7.3, 143.8, 12.0, 149.7, 13.0);
    ctx.bezierCurveTo(150.5, 13.1, 151.3, 13.2, 152.1, 13.2);
    ctx.bezierCurveTo(154.3, 13.2, 156.4, 12.8, 158.4, 12.0);
    ctx.lineTo(163.5, 20.1);
    ctx.bezierCurveTo(163.6, 20.3, 163.8, 20.4, 164.1, 20.5);
    ctx.lineTo(164.1, 20.5);
    ctx.bezierCurveTo(164.5, 20.5, 164.8, 20.2, 164.9, 19.8);
    ctx.lineTo(165.4, 10.5);
    ctx.bezierCurveTo(165.3, 10.2, 165.5, 9.9, 165.8, 9.8);
    ctx.bezierCurveTo(166.0, 9.6, 166.2, 9.5, 166.5, 9.4);
    ctx.bezierCurveTo(168.4, 8.6, 171.2, 7.4, 172.4, 2.3);
    ctx.bezierCurveTo(172.5, 1.6, 172.6, 0.9, 172.6, 0.2);
    ctx.lineTo(171.7, 0.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(165.0, 1.8);
    ctx.bezierCurveTo(164.8, 2.4, 164.0, 2.7, 163.3, 2.4);
    ctx.bezierCurveTo(162.7, 2.1, 162.4, 1.4, 162.6, 0.7);
    ctx.bezierCurveTo(162.7, 0.5, 162.9, 0.3, 163.1, 0.2);
    ctx.bezierCurveTo(163.5, -0.0, 163.9, -0.1, 164.3, 0.1);
    ctx.bezierCurveTo(164.4, 0.1, 164.5, 0.2, 164.5, 0.2);
    ctx.bezierCurveTo(165.0, 0.5, 165.3, 1.2, 165.0, 1.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(155.2, 1.3);
    ctx.bezierCurveTo(154.9, 1.9, 154.2, 2.2, 153.5, 1.9);
    ctx.bezierCurveTo(152.9, 1.6, 152.5, 0.9, 152.8, 0.2);
    ctx.bezierCurveTo(152.8, 0.2, 152.8, 0.2, 152.8, 0.2);
    ctx.lineTo(155.2, 0.2);
    ctx.bezierCurveTo(155.3, 0.5, 155.4, 0.9, 155.2, 1.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(146.2, 0.2);
    ctx.bezierCurveTo(146.2, 0.3, 146.2, 0.3, 146.2, 0.4);
    ctx.bezierCurveTo(145.9, 1.0, 145.2, 1.3, 144.5, 1.0);
    ctx.bezierCurveTo(144.1, 0.9, 143.9, 0.6, 143.8, 0.2);
    ctx.lineTo(146.2, 0.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(164.5, 402.7);
    ctx.bezierCurveTo(155.0, 398.6, 146.9, 398.9, 140.2, 403.4);
    ctx.bezierCurveTo(139.5, 403.9, 134.4, 407.6, 135.7, 414.0);
    ctx.bezierCurveTo(135.7, 414.1, 135.7, 414.2, 135.7, 414.2);
    ctx.lineTo(136.5, 414.2);
    ctx.bezierCurveTo(136.4, 414.1, 136.4, 414.0, 136.4, 413.9);
    ctx.bezierCurveTo(135.2, 408.0, 140.0, 404.6, 140.5, 404.2);
    ctx.bezierCurveTo(147.0, 399.9, 154.8, 399.7, 164.1, 403.6);
    ctx.bezierCurveTo(165.2, 404.0, 171.6, 408.3, 171.7, 414.2);
    ctx.lineTo(172.6, 414.2);
    ctx.bezierCurveTo(172.6, 407.8, 165.6, 403.2, 164.5, 402.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(164.6, 414.2);
    ctx.lineTo(163.1, 414.2);
    ctx.bezierCurveTo(163.4, 414.0, 163.9, 413.9, 164.3, 414.1);
    ctx.bezierCurveTo(164.4, 414.1, 164.5, 414.2, 164.6, 414.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(155.2, 414.2);
    ctx.lineTo(152.8, 414.2);
    ctx.lineTo(152.8, 414.2);
    ctx.bezierCurveTo(153.1, 413.6, 153.9, 413.3, 154.5, 413.6);
    ctx.bezierCurveTo(154.8, 413.7, 155.1, 414.0, 155.2, 414.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(146.2, 414.2);
    ctx.lineTo(143.8, 414.2);
    ctx.bezierCurveTo(143.7, 414.0, 143.7, 413.6, 143.8, 413.3);
    ctx.bezierCurveTo(144.1, 412.7, 144.8, 412.4, 145.5, 412.7);
    ctx.bezierCurveTo(146.1, 413.0, 146.4, 413.6, 146.2, 414.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(131.0, 34.7);
    ctx.bezierCurveTo(130.8, 34.7, 130.6, 34.6, 130.5, 34.4);
    ctx.lineTo(126.3, 27.7);
    ctx.lineTo(126.3, 27.7);
    ctx.bezierCurveTo(124.0, 28.6, 121.5, 28.9, 119.0, 28.5);
    ctx.bezierCurveTo(114.2, 27.7, 108.6, 23.8, 107.4, 17.8);
    ctx.bezierCurveTo(106.4, 12.5, 110.7, 9.4, 111.2, 9.0);
    ctx.bezierCurveTo(116.8, 5.2, 123.5, 5.0, 131.4, 8.4);
    ctx.bezierCurveTo(132.4, 8.9, 139.3, 13.4, 137.9, 19.7);
    ctx.bezierCurveTo(136.9, 23.9, 134.6, 24.9, 133.0, 25.6);
    ctx.bezierCurveTo(132.8, 25.6, 132.6, 25.7, 132.4, 25.9);
    ctx.bezierCurveTo(132.2, 26.0, 132.1, 26.2, 132.1, 26.5);
    ctx.lineTo(131.7, 34.1);
    ctx.bezierCurveTo(131.6, 34.5, 131.4, 34.7, 131.0, 34.7);
    ctx.lineTo(131.0, 34.7);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(126.8, 27.3);
    ctx.lineTo(130.9, 33.8);
    ctx.lineTo(131.2, 26.4);
    ctx.bezierCurveTo(131.2, 25.9, 131.5, 25.4, 132.0, 25.2);
    ctx.lineTo(132.6, 24.9);
    ctx.bezierCurveTo(134.1, 24.2, 136.2, 23.4, 137.1, 19.5);
    ctx.bezierCurveTo(138.4, 13.8, 132.0, 9.5, 131.0, 9.2);
    ctx.bezierCurveTo(123.3, 6.0, 116.8, 6.1, 111.5, 9.7);
    ctx.bezierCurveTo(111.0, 10.0, 107.1, 12.8, 108.0, 17.7);
    ctx.bezierCurveTo(109.2, 23.4, 114.4, 27.1, 119.0, 27.8);
    ctx.bezierCurveTo(121.3, 28.2, 123.7, 27.9, 125.9, 27.0);
    ctx.bezierCurveTo(126.2, 27.0, 126.6, 27.1, 126.8, 27.3);
    ctx.lineTo(126.8, 27.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(129.8, 18.4);
    ctx.bezierCurveTo(130.0, 17.9, 130.7, 17.6, 131.2, 17.9);
    ctx.bezierCurveTo(131.8, 18.1, 132.0, 18.7, 131.8, 19.2);
    ctx.bezierCurveTo(131.6, 19.8, 131.0, 20.0, 130.4, 19.8);
    ctx.bezierCurveTo(129.9, 19.5, 129.6, 18.9, 129.8, 18.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(121.7, 18.0);
    ctx.bezierCurveTo(121.9, 17.5, 122.5, 17.2, 123.1, 17.5);
    ctx.bezierCurveTo(123.6, 17.7, 123.9, 18.3, 123.7, 18.8);
    ctx.bezierCurveTo(123.4, 19.4, 122.8, 19.6, 122.3, 19.4);
    ctx.bezierCurveTo(121.7, 19.1, 121.5, 18.5, 121.7, 18.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(114.2, 17.2);
    ctx.bezierCurveTo(114.4, 16.7, 115.0, 16.5, 115.6, 16.7);
    ctx.bezierCurveTo(116.1, 17.0, 116.4, 17.6, 116.2, 18.1);
    ctx.bezierCurveTo(116.0, 18.6, 115.3, 18.8, 114.8, 18.6);
    ctx.bezierCurveTo(114.2, 18.4, 114.0, 17.8, 114.2, 17.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(152.3, 72.0);
    ctx.bezierCurveTo(152.1, 72.0, 151.9, 71.9, 151.8, 71.7);
    ctx.lineTo(147.8, 65.3);
    ctx.lineTo(147.8, 65.3);
    ctx.bezierCurveTo(145.6, 66.1, 143.3, 66.4, 140.9, 66.1);
    ctx.bezierCurveTo(136.3, 65.3, 131.0, 61.6, 129.9, 55.9);
    ctx.bezierCurveTo(128.9, 50.8, 133.0, 47.9, 133.5, 47.5);
    ctx.bezierCurveTo(138.8, 43.9, 145.2, 43.7, 152.7, 46.9);
    ctx.bezierCurveTo(153.7, 47.4, 160.2, 51.7, 158.9, 57.6);
    ctx.bezierCurveTo(157.9, 61.6, 155.7, 62.6, 154.2, 63.2);
    ctx.bezierCurveTo(154.0, 63.3, 153.9, 63.4, 153.7, 63.5);
    ctx.bezierCurveTo(153.5, 63.6, 153.3, 63.9, 153.3, 64.1);
    ctx.lineTo(153.0, 71.4);
    ctx.bezierCurveTo(152.9, 71.7, 152.6, 72.0, 152.3, 72.0);
    ctx.lineTo(152.3, 72.0);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(148.3, 64.9);
    ctx.lineTo(152.2, 71.0);
    ctx.lineTo(152.5, 64.0);
    ctx.bezierCurveTo(152.5, 63.6, 152.8, 63.1, 153.2, 62.9);
    ctx.lineTo(153.9, 62.6);
    ctx.bezierCurveTo(155.3, 62.0, 157.3, 61.2, 158.1, 57.5);
    ctx.bezierCurveTo(159.3, 52.1, 153.2, 48.0, 152.3, 47.7);
    ctx.bezierCurveTo(145.0, 44.6, 138.8, 44.7, 133.7, 48.2);
    ctx.bezierCurveTo(133.3, 48.4, 129.6, 51.2, 130.4, 55.8);
    ctx.bezierCurveTo(131.5, 61.2, 136.5, 64.7, 140.9, 65.4);
    ctx.bezierCurveTo(143.1, 65.7, 145.4, 65.5, 147.5, 64.6);
    ctx.bezierCurveTo(147.8, 64.5, 148.1, 64.7, 148.3, 64.9);
    ctx.lineTo(148.3, 64.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(151.2, 56.4);
    ctx.bezierCurveTo(151.4, 55.9, 152.0, 55.7, 152.5, 55.9);
    ctx.bezierCurveTo(153.0, 56.1, 153.2, 56.7, 153.0, 57.2);
    ctx.bezierCurveTo(152.8, 57.7, 152.2, 57.9, 151.7, 57.7);
    ctx.bezierCurveTo(151.2, 57.5, 150.9, 56.9, 151.2, 56.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(143.4, 56.0);
    ctx.bezierCurveTo(143.6, 55.5, 144.2, 55.3, 144.7, 55.5);
    ctx.bezierCurveTo(145.2, 55.8, 145.5, 56.3, 145.3, 56.8);
    ctx.bezierCurveTo(145.1, 57.3, 144.5, 57.6, 144.0, 57.3);
    ctx.bezierCurveTo(143.4, 57.1, 143.2, 56.5, 143.4, 56.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(136.3, 55.3);
    ctx.bezierCurveTo(136.5, 54.8, 137.1, 54.6, 137.6, 54.8);
    ctx.bezierCurveTo(138.1, 55.0, 138.4, 55.6, 138.2, 56.1);
    ctx.bezierCurveTo(138.0, 56.6, 137.4, 56.8, 136.8, 56.6);
    ctx.bezierCurveTo(136.3, 56.4, 136.1, 55.8, 136.3, 55.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(239.9, 218.4);
    ctx.bezierCurveTo(239.7, 218.4, 239.4, 218.3, 239.3, 218.1);
    ctx.lineTo(234.0, 209.6);
    ctx.lineTo(234.0, 209.6);
    ctx.bezierCurveTo(231.1, 210.8, 228.0, 211.1, 224.9, 210.6);
    ctx.bezierCurveTo(218.8, 209.6, 211.8, 204.7, 210.4, 197.2);
    ctx.bezierCurveTo(209.1, 190.5, 214.4, 186.7, 215.1, 186.2);
    ctx.bezierCurveTo(222.1, 181.5, 230.5, 181.2, 240.4, 185.5);
    ctx.bezierCurveTo(241.6, 186.0, 250.4, 191.8, 248.5, 199.6);
    ctx.bezierCurveTo(247.3, 204.8, 244.4, 206.1, 242.4, 207.0);
    ctx.bezierCurveTo(242.2, 207.0, 241.9, 207.2, 241.7, 207.3);
    ctx.bezierCurveTo(241.4, 207.5, 241.2, 207.8, 241.3, 208.1);
    ctx.lineTo(240.8, 217.7);
    ctx.bezierCurveTo(240.6, 218.2, 240.4, 218.4, 239.9, 218.4);
    ctx.lineTo(239.9, 218.4);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(234.7, 209.1);
    ctx.lineTo(239.7, 217.2);
    ctx.lineTo(240.2, 208.0);
    ctx.bezierCurveTo(240.2, 207.3, 240.6, 206.7, 241.2, 206.5);
    ctx.lineTo(242.0, 206.1);
    ctx.bezierCurveTo(243.9, 205.3, 246.5, 204.2, 247.5, 199.4);
    ctx.bezierCurveTo(249.2, 192.2, 241.2, 186.9, 239.9, 186.4);
    ctx.bezierCurveTo(230.3, 182.3, 222.2, 182.5, 215.4, 187.0);
    ctx.bezierCurveTo(214.9, 187.4, 210.0, 190.9, 211.1, 197.0);
    ctx.bezierCurveTo(212.6, 204.1, 219.1, 208.8, 224.9, 209.7);
    ctx.bezierCurveTo(227.9, 210.2, 230.8, 209.8, 233.6, 208.7);
    ctx.bezierCurveTo(234.0, 208.6, 234.4, 208.8, 234.7, 209.1);
    ctx.lineTo(234.7, 209.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(238.4, 198.0);
    ctx.bezierCurveTo(238.7, 197.3, 239.5, 197.0, 240.2, 197.3);
    ctx.bezierCurveTo(240.9, 197.6, 241.2, 198.4, 240.9, 199.0);
    ctx.bezierCurveTo(240.6, 199.7, 239.8, 200.0, 239.2, 199.7);
    ctx.bezierCurveTo(238.5, 199.4, 238.1, 198.6, 238.4, 198.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(228.2, 197.4);
    ctx.bezierCurveTo(228.5, 196.8, 229.3, 196.5, 230.0, 196.8);
    ctx.bezierCurveTo(230.7, 197.1, 231.0, 197.9, 230.7, 198.5);
    ctx.bezierCurveTo(230.4, 199.2, 229.6, 199.5, 229.0, 199.2);
    ctx.bezierCurveTo(228.3, 198.9, 227.9, 198.1, 228.2, 197.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(218.8, 196.5);
    ctx.bezierCurveTo(219.1, 195.9, 219.9, 195.6, 220.6, 195.9);
    ctx.bezierCurveTo(221.3, 196.2, 221.6, 196.9, 221.3, 197.6);
    ctx.bezierCurveTo(221.0, 198.3, 220.3, 198.5, 219.6, 198.3);
    ctx.bezierCurveTo(218.9, 198.0, 218.6, 197.2, 218.8, 196.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(124.7, 319.2);
    ctx.bezierCurveTo(124.4, 319.2, 124.1, 319.1, 124.0, 318.8);
    ctx.lineTo(118.1, 309.7);
    ctx.lineTo(118.1, 309.7);
    ctx.bezierCurveTo(114.9, 310.9, 111.4, 311.3, 108.0, 310.8);
    ctx.bezierCurveTo(101.2, 309.8, 93.4, 304.4, 91.8, 296.3);
    ctx.bezierCurveTo(90.3, 289.1, 96.3, 284.9, 97.0, 284.4);
    ctx.bezierCurveTo(104.8, 279.3, 114.2, 279.0, 125.2, 283.6);
    ctx.bezierCurveTo(126.6, 284.2, 136.3, 290.5, 134.3, 298.8);
    ctx.bezierCurveTo(132.9, 304.5, 129.7, 305.9, 127.5, 306.8);
    ctx.bezierCurveTo(127.2, 306.9, 126.9, 307.0, 126.7, 307.2);
    ctx.bezierCurveTo(126.4, 307.3, 126.2, 307.7, 126.2, 308.0);
    ctx.lineTo(125.7, 318.4);
    ctx.bezierCurveTo(125.7, 318.8, 125.4, 319.1, 125.1, 319.2);
    ctx.lineTo(124.7, 319.2);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(118.0, 308.7);
    ctx.bezierCurveTo(118.4, 308.7, 118.7, 308.9, 118.9, 309.2);
    ctx.lineTo(118.9, 309.2);
    ctx.lineTo(124.5, 318.0);
    ctx.lineTo(125.0, 308.0);
    ctx.bezierCurveTo(125.0, 307.3, 125.4, 306.7, 126.1, 306.4);
    ctx.lineTo(127.0, 306.0);
    ctx.bezierCurveTo(129.1, 305.1, 132.0, 303.9, 133.2, 298.7);
    ctx.bezierCurveTo(135.0, 291.0, 126.1, 285.2, 124.7, 284.7);
    ctx.bezierCurveTo(114.0, 280.3, 104.9, 280.5, 97.4, 285.4);
    ctx.bezierCurveTo(96.8, 285.8, 91.3, 289.6, 92.6, 296.2);
    ctx.bezierCurveTo(94.2, 303.9, 101.5, 308.9, 108.0, 309.9);
    ctx.bezierCurveTo(111.2, 310.4, 114.6, 310.0, 117.6, 308.8);
    ctx.bezierCurveTo(117.7, 308.7, 117.9, 308.7, 118.0, 308.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(122.9, 297.3);
    ctx.bezierCurveTo(123.1, 296.6, 123.9, 296.1, 124.7, 296.3);
    ctx.bezierCurveTo(125.5, 296.5, 126.0, 297.3, 125.8, 298.0);
    ctx.bezierCurveTo(125.7, 298.8, 124.9, 299.2, 124.1, 299.0);
    ctx.bezierCurveTo(123.3, 298.8, 122.7, 298.1, 122.9, 297.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(111.6, 296.8);
    ctx.bezierCurveTo(111.7, 296.0, 112.5, 295.6, 113.4, 295.7);
    ctx.bezierCurveTo(114.2, 295.9, 114.7, 296.7, 114.5, 297.5);
    ctx.bezierCurveTo(114.3, 298.2, 113.5, 298.7, 112.7, 298.5);
    ctx.bezierCurveTo(111.9, 298.3, 111.4, 297.5, 111.6, 296.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(101.1, 295.8);
    ctx.bezierCurveTo(101.3, 295.0, 102.1, 294.6, 102.9, 294.8);
    ctx.bezierCurveTo(103.7, 295.0, 104.2, 295.7, 104.0, 296.5);
    ctx.bezierCurveTo(103.8, 297.2, 103.0, 297.7, 102.2, 297.5);
    ctx.bezierCurveTo(101.4, 297.3, 100.9, 296.5, 101.1, 295.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(220.7, 347.2);
    ctx.bezierCurveTo(220.4, 347.2, 220.1, 347.1, 220.0, 346.8);
    ctx.lineTo(214.1, 337.7);
    ctx.lineTo(214.1, 337.7);
    ctx.bezierCurveTo(210.9, 338.9, 207.4, 339.3, 204.0, 338.8);
    ctx.bezierCurveTo(197.2, 337.8, 189.4, 332.4, 187.8, 324.3);
    ctx.bezierCurveTo(186.3, 317.1, 192.3, 312.9, 193.0, 312.4);
    ctx.bezierCurveTo(200.8, 307.3, 210.2, 307.0, 221.2, 311.6);
    ctx.bezierCurveTo(222.6, 312.2, 232.3, 318.5, 230.3, 326.8);
    ctx.bezierCurveTo(228.9, 332.5, 225.7, 333.9, 223.5, 334.8);
    ctx.bezierCurveTo(223.2, 334.9, 222.9, 335.0, 222.7, 335.2);
    ctx.bezierCurveTo(222.4, 335.3, 222.2, 335.7, 222.2, 336.0);
    ctx.lineTo(221.7, 346.4);
    ctx.bezierCurveTo(221.6, 346.9, 221.2, 347.2, 220.7, 347.2);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(214.1, 336.7);
    ctx.bezierCurveTo(214.5, 336.7, 214.8, 336.9, 215.0, 337.2);
    ctx.lineTo(220.6, 346.0);
    ctx.lineTo(221.1, 336.0);
    ctx.bezierCurveTo(221.1, 335.3, 221.5, 334.7, 222.2, 334.4);
    ctx.lineTo(223.1, 334.0);
    ctx.bezierCurveTo(225.2, 333.1, 228.1, 331.9, 229.3, 326.7);
    ctx.bezierCurveTo(231.1, 319.0, 222.2, 313.2, 220.8, 312.7);
    ctx.bezierCurveTo(210.2, 308.3, 201.0, 308.5, 193.5, 313.4);
    ctx.bezierCurveTo(192.9, 313.8, 187.4, 317.6, 188.7, 324.2);
    ctx.bezierCurveTo(190.3, 331.9, 197.6, 336.9, 204.1, 337.9);
    ctx.bezierCurveTo(207.3, 338.4, 210.7, 338.0, 213.7, 336.8);
    ctx.bezierCurveTo(213.8, 336.7, 213.9, 336.7, 214.1, 336.7);
    ctx.lineTo(214.1, 336.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(218.9, 325.3);
    ctx.bezierCurveTo(219.1, 324.6, 219.9, 324.1, 220.7, 324.3);
    ctx.bezierCurveTo(221.5, 324.5, 222.0, 325.3, 221.8, 326.0);
    ctx.bezierCurveTo(221.7, 326.8, 220.9, 327.2, 220.1, 327.0);
    ctx.bezierCurveTo(219.3, 326.9, 218.8, 326.1, 218.9, 325.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(207.7, 324.8);
    ctx.bezierCurveTo(207.8, 324.0, 208.6, 323.6, 209.4, 323.8);
    ctx.bezierCurveTo(210.3, 324.0, 210.8, 324.7, 210.6, 325.5);
    ctx.bezierCurveTo(210.4, 326.2, 209.6, 326.7, 208.8, 326.5);
    ctx.bezierCurveTo(208.0, 326.3, 207.5, 325.5, 207.7, 324.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(197.1, 323.8);
    ctx.bezierCurveTo(197.3, 323.0, 198.1, 322.6, 198.9, 322.8);
    ctx.bezierCurveTo(199.7, 323.0, 200.2, 323.7, 200.0, 324.5);
    ctx.bezierCurveTo(199.8, 325.2, 199.0, 325.7, 198.2, 325.5);
    ctx.bezierCurveTo(197.4, 325.3, 196.9, 324.5, 197.1, 323.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(319.7, 400.2);
    ctx.bezierCurveTo(319.4, 400.2, 319.1, 400.1, 319.0, 399.8);
    ctx.lineTo(313.1, 390.2);
    ctx.lineTo(313.1, 390.2);
    ctx.bezierCurveTo(309.9, 391.5, 306.4, 391.9, 303.0, 391.4);
    ctx.bezierCurveTo(296.2, 390.3, 288.4, 384.7, 286.8, 376.1);
    ctx.bezierCurveTo(285.3, 368.5, 291.3, 364.1, 292.0, 363.6);
    ctx.bezierCurveTo(299.8, 358.2, 309.3, 357.9, 320.2, 362.7);
    ctx.bezierCurveTo(321.6, 363.3, 331.2, 369.9, 329.3, 378.7);
    ctx.bezierCurveTo(327.9, 384.7, 324.7, 386.2, 322.5, 387.2);
    ctx.bezierCurveTo(322.2, 387.3, 322.0, 387.5, 321.7, 387.6);
    ctx.bezierCurveTo(321.4, 387.8, 321.2, 388.1, 321.2, 388.4);
    ctx.lineTo(320.7, 399.4);
    ctx.bezierCurveTo(320.7, 399.8, 320.4, 400.1, 320.1, 400.2);
    ctx.bezierCurveTo(319.8, 400.1, 319.8, 400.2, 319.7, 400.2);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(313.9, 389.6);
    ctx.lineTo(319.5, 398.9);
    ctx.lineTo(320.0, 388.3);
    ctx.bezierCurveTo(320.0, 387.6, 320.4, 387.0, 321.0, 386.7);
    ctx.bezierCurveTo(321.3, 386.6, 321.6, 386.4, 321.9, 386.3);
    ctx.bezierCurveTo(324.0, 385.3, 326.9, 384.1, 328.1, 378.5);
    ctx.bezierCurveTo(329.9, 370.3, 321.0, 364.2, 319.6, 363.6);
    ctx.bezierCurveTo(309.0, 358.9, 299.8, 359.2, 292.3, 364.4);
    ctx.bezierCurveTo(291.7, 364.8, 286.2, 368.9, 287.5, 375.9);
    ctx.bezierCurveTo(289.0, 384.0, 296.4, 389.3, 302.9, 390.4);
    ctx.bezierCurveTo(306.1, 390.9, 309.5, 390.5, 312.5, 389.3);
    ctx.bezierCurveTo(313.0, 389.0, 313.6, 389.1, 313.9, 389.6);
    ctx.bezierCurveTo(313.9, 389.6, 313.9, 389.6, 313.9, 389.6);
    ctx.lineTo(313.9, 389.6);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(319.4, 375.9);
    ctx.bezierCurveTo(320.2, 375.9, 320.9, 376.6, 320.9, 377.4);
    ctx.bezierCurveTo(320.9, 378.2, 320.2, 378.9, 319.4, 378.9);
    ctx.bezierCurveTo(318.6, 378.9, 317.9, 378.2, 317.9, 377.4);
    ctx.bezierCurveTo(317.9, 376.6, 318.6, 375.9, 319.4, 375.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(308.0, 375.4);
    ctx.bezierCurveTo(308.9, 375.4, 309.5, 376.1, 309.5, 376.9);
    ctx.bezierCurveTo(309.5, 377.7, 308.9, 378.4, 308.0, 378.4);
    ctx.bezierCurveTo(307.2, 378.4, 306.5, 377.7, 306.5, 376.9);
    ctx.bezierCurveTo(306.5, 376.1, 307.2, 375.4, 308.0, 375.4);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(297.6, 374.3);
    ctx.bezierCurveTo(298.4, 374.3, 299.1, 375.0, 299.1, 375.8);
    ctx.bezierCurveTo(299.1, 376.6, 298.4, 377.3, 297.6, 377.3);
    ctx.bezierCurveTo(296.8, 377.3, 296.1, 376.6, 296.1, 375.8);
    ctx.bezierCurveTo(296.1, 375.0, 296.8, 374.3, 297.6, 374.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(228.2, 54.8);
    ctx.bezierCurveTo(227.9, 54.8, 227.7, 54.7, 227.5, 54.4);
    ctx.lineTo(221.6, 44.7);
    ctx.lineTo(221.6, 44.7);
    ctx.bezierCurveTo(218.4, 46.0, 214.9, 46.4, 211.5, 45.9);
    ctx.bezierCurveTo(204.7, 44.8, 196.9, 39.2, 195.3, 30.6);
    ctx.bezierCurveTo(193.8, 23.0, 199.8, 18.6, 200.5, 18.1);
    ctx.bezierCurveTo(208.3, 12.7, 217.8, 12.4, 228.7, 17.2);
    ctx.bezierCurveTo(230.1, 17.8, 239.8, 24.4, 237.8, 33.2);
    ctx.bezierCurveTo(236.4, 39.2, 233.2, 40.7, 231.0, 41.7);
    ctx.bezierCurveTo(230.8, 41.8, 230.5, 42.0, 230.2, 42.1);
    ctx.bezierCurveTo(229.9, 42.3, 229.8, 42.6, 229.7, 42.9);
    ctx.lineTo(229.2, 53.9);
    ctx.bezierCurveTo(229.2, 54.3, 229.0, 54.6, 228.6, 54.7);
    ctx.bezierCurveTo(228.3, 54.7, 228.3, 54.8, 228.2, 54.8);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(222.4, 44.2);
    ctx.lineTo(228.0, 53.5);
    ctx.lineTo(228.5, 42.9);
    ctx.bezierCurveTo(228.6, 42.2, 228.9, 41.6, 229.5, 41.2);
    ctx.bezierCurveTo(229.8, 41.1, 230.1, 40.9, 230.4, 40.8);
    ctx.bezierCurveTo(232.5, 39.8, 235.4, 38.6, 236.6, 33.0);
    ctx.bezierCurveTo(238.4, 24.8, 229.5, 18.7, 228.1, 18.1);
    ctx.bezierCurveTo(217.5, 13.4, 208.3, 13.7, 200.8, 18.9);
    ctx.bezierCurveTo(200.2, 19.3, 194.7, 23.4, 196.0, 30.4);
    ctx.bezierCurveTo(197.6, 38.5, 204.9, 43.8, 211.4, 44.9);
    ctx.bezierCurveTo(214.7, 45.4, 218.0, 45.0, 221.0, 43.8);
    ctx.bezierCurveTo(221.5, 43.6, 222.1, 43.8, 222.4, 44.2);
    ctx.lineTo(222.4, 44.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(227.9, 30.5);
    ctx.bezierCurveTo(228.8, 30.5, 229.4, 31.2, 229.4, 32.0);
    ctx.bezierCurveTo(229.4, 32.8, 228.8, 33.5, 227.9, 33.5);
    ctx.bezierCurveTo(227.1, 33.5, 226.4, 32.8, 226.4, 32.0);
    ctx.bezierCurveTo(226.4, 31.2, 227.1, 30.5, 227.9, 30.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(216.6, 30.0);
    ctx.bezierCurveTo(217.5, 30.0, 218.1, 30.7, 218.1, 31.5);
    ctx.bezierCurveTo(218.1, 32.3, 217.5, 33.0, 216.6, 33.0);
    ctx.bezierCurveTo(215.8, 33.0, 215.1, 32.3, 215.1, 31.5);
    ctx.bezierCurveTo(215.1, 30.7, 215.8, 30.0, 216.6, 30.0);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(206.1, 28.9);
    ctx.bezierCurveTo(207.0, 28.9, 207.6, 29.6, 207.6, 30.4);
    ctx.bezierCurveTo(207.6, 31.2, 207.0, 31.9, 206.1, 31.9);
    ctx.bezierCurveTo(205.3, 31.9, 204.6, 31.2, 204.6, 30.4);
    ctx.bezierCurveTo(204.6, 29.6, 205.3, 28.9, 206.1, 28.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group
    ctx.restore();

    // layer1/Group/Compound Path
    ctx.save();
    ctx.beginPath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(59.3, 367.6);
    ctx.bezierCurveTo(59.1, 367.7, 58.8, 367.8, 58.6, 367.7);
    ctx.bezierCurveTo(57.9, 367.7, 57.4, 367.2, 57.3, 366.5);
    ctx.lineTo(54.3, 352.3);
    ctx.bezierCurveTo(54.2, 352.0, 54.0, 351.8, 53.7, 351.6);
    ctx.lineTo(52.5, 351.3);
    ctx.bezierCurveTo(49.3, 350.4, 44.6, 349.1, 41.5, 341.4);
    ctx.bezierCurveTo(36.9, 330.0, 48.5, 319.6, 50.4, 318.4);
    ctx.bezierCurveTo(64.1, 310.0, 76.9, 308.6, 88.5, 314.1);
    ctx.bezierCurveTo(89.5, 314.6, 98.6, 319.3, 98.2, 329.7);
    ctx.bezierCurveTo(97.8, 341.3, 88.5, 350.2, 79.6, 353.0);
    ctx.bezierCurveTo(75.2, 354.4, 70.5, 354.5, 66.0, 353.4);
    ctx.lineTo(60.3, 366.8);
    ctx.bezierCurveTo(60.0, 367.2, 59.7, 367.5, 59.3, 367.6);
    ctx.closePath();

    // layer1/Group/Compound Path/Path
    ctx.moveTo(59.7, 315.8);
    ctx.bezierCurveTo(56.7, 317.0, 53.9, 318.5, 51.2, 320.1);
    ctx.bezierCurveTo(51.1, 320.2, 38.8, 329.8, 43.2, 340.6);
    ctx.bezierCurveTo(46.0, 347.4, 50.0, 348.5, 52.9, 349.3);
    ctx.bezierCurveTo(53.3, 349.4, 53.7, 349.5, 54.1, 349.7);
    ctx.bezierCurveTo(55.1, 350.1, 55.8, 350.9, 56.1, 351.9);
    ctx.lineTo(58.8, 364.6);
    ctx.lineTo(64.0, 352.4);
    ctx.bezierCurveTo(64.3, 351.7, 65.1, 351.2, 65.9, 351.4);
    ctx.bezierCurveTo(70.1, 352.4, 74.5, 352.3, 78.7, 351.1);
    ctx.bezierCurveTo(87.0, 348.5, 95.6, 340.3, 95.9, 329.7);
    ctx.bezierCurveTo(96.2, 320.6, 88.2, 316.4, 87.3, 316.0);
    ctx.bezierCurveTo(78.9, 311.8, 69.6, 311.8, 59.7, 315.8);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(54.4, 335.7);
    ctx.bezierCurveTo(55.5, 335.7, 56.4, 336.6, 56.4, 337.7);
    ctx.bezierCurveTo(56.4, 338.9, 55.5, 339.7, 54.4, 339.7);
    ctx.bezierCurveTo(53.3, 339.7, 52.4, 338.9, 52.4, 337.7);
    ctx.bezierCurveTo(52.4, 336.6, 53.3, 335.7, 54.4, 335.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(69.4, 332.9);
    ctx.bezierCurveTo(70.5, 332.9, 71.4, 333.8, 71.4, 334.9);
    ctx.bezierCurveTo(71.4, 336.1, 70.5, 336.9, 69.4, 336.9);
    ctx.bezierCurveTo(68.3, 336.9, 67.4, 336.1, 67.4, 334.9);
    ctx.bezierCurveTo(67.4, 333.8, 68.3, 332.9, 69.4, 332.9);
    ctx.closePath();
    ctx.fill();

    // layer1/Group/Path
    ctx.beginPath();
    ctx.moveTo(83.2, 329.5);
    ctx.bezierCurveTo(84.3, 329.5, 85.2, 330.4, 85.2, 331.5);
    ctx.bezierCurveTo(85.2, 332.7, 84.3, 333.5, 83.2, 333.5);
    ctx.bezierCurveTo(82.1, 333.5, 81.2, 332.7, 81.2, 331.5);
    ctx.bezierCurveTo(81.2, 330.4, 82.1, 329.5, 83.2, 329.5);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.restore();
    ctx.beginPath();
    ctx.moveTo(412.4, 134.3);
    ctx.bezierCurveTo(413.3, 133.7, 414.2, 133.2, 415.2, 132.8);
    ctx.lineTo(415.2, 132.0);
    ctx.bezierCurveTo(414.1, 132.5, 413.1, 133.1, 412.2, 133.7);
    ctx.bezierCurveTo(409.7, 135.6, 408.5, 138.7, 409.0, 141.7);
    ctx.bezierCurveTo(409.7, 145.3, 412.0, 148.3, 415.2, 150.1);
    ctx.lineTo(415.2, 149.4);
    ctx.bezierCurveTo(412.2, 147.7, 410.2, 144.9, 409.5, 141.6);
    ctx.bezierCurveTo(409.0, 138.8, 410.2, 136.0, 412.4, 134.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(415.2, 140.7);
    ctx.lineTo(415.2, 142.5);
    ctx.bezierCurveTo(414.8, 142.3, 414.5, 141.8, 414.6, 141.4);
    ctx.bezierCurveTo(414.7, 141.1, 414.9, 140.8, 415.2, 140.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(14.0, 133.2);
    ctx.bezierCurveTo(8.7, 130.8, 4.0, 130.4, 0.0, 132.0);
    ctx.lineTo(0.0, 132.8);
    ctx.bezierCurveTo(3.9, 131.1, 8.5, 131.5, 13.6, 133.9);
    ctx.bezierCurveTo(14.5, 134.2, 19.9, 138.1, 18.8, 143.2);
    ctx.bezierCurveTo(18.1, 146.7, 16.3, 147.5, 15.0, 148.1);
    ctx.lineTo(14.5, 148.4);
    ctx.bezierCurveTo(14.1, 148.6, 13.8, 149.0, 13.8, 149.4);
    ctx.lineTo(13.5, 156.1);
    ctx.lineTo(10.1, 150.2);
    ctx.bezierCurveTo(10.0, 150.0, 9.7, 149.9, 9.4, 149.9);
    ctx.bezierCurveTo(7.6, 150.7, 5.5, 151.0, 3.6, 150.7);
    ctx.bezierCurveTo(2.3, 150.5, 1.1, 150.0, 0.0, 149.4);
    ctx.lineTo(0.0, 150.1);
    ctx.bezierCurveTo(1.1, 150.7, 2.3, 151.1, 3.6, 151.4);
    ctx.bezierCurveTo(4.2, 151.5, 4.8, 151.5, 5.3, 151.5);
    ctx.bezierCurveTo(6.8, 151.5, 8.3, 151.2, 9.7, 150.6);
    ctx.lineTo(13.2, 156.7);
    ctx.bezierCurveTo(13.3, 156.9, 13.5, 157.0, 13.7, 157.0);
    ctx.bezierCurveTo(14.0, 157.0, 14.1, 156.8, 14.3, 156.4);
    ctx.lineTo(14.6, 149.4);
    ctx.bezierCurveTo(14.5, 149.2, 14.7, 149.0, 14.9, 148.9);
    ctx.bezierCurveTo(15.0, 148.8, 15.2, 148.7, 15.3, 148.6);
    ctx.bezierCurveTo(16.7, 148.0, 18.6, 147.1, 19.4, 143.3);
    ctx.bezierCurveTo(20.6, 137.7, 14.8, 133.6, 14.0, 133.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(13.2, 141.7);
    ctx.bezierCurveTo(13.6, 141.6, 14.1, 141.8, 14.3, 142.3);
    ctx.bezierCurveTo(14.5, 142.8, 14.2, 143.3, 13.8, 143.5);
    ctx.bezierCurveTo(13.3, 143.7, 12.8, 143.4, 12.6, 142.9);
    ctx.bezierCurveTo(12.4, 142.4, 12.7, 141.9, 13.2, 141.7);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(6.3, 141.3);
    ctx.bezierCurveTo(6.8, 141.2, 7.3, 141.4, 7.5, 141.9);
    ctx.bezierCurveTo(7.6, 142.4, 7.4, 142.9, 6.9, 143.1);
    ctx.bezierCurveTo(6.4, 143.3, 5.9, 143.0, 5.8, 142.5);
    ctx.bezierCurveTo(5.6, 142.0, 5.8, 141.5, 6.3, 141.3);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(164.3, 0.1);
    ctx.bezierCurveTo(164.4, 0.1, 164.5, 0.2, 164.5, 0.2);
    ctx.lineTo(163.1, 0.2);
    ctx.bezierCurveTo(163.5, -0.0, 163.9, -0.1, 164.3, 0.1);
    ctx.closePath();
    ctx.fill();

    // layer1/Path
    ctx.beginPath();
    ctx.moveTo(331.0, 0.2);
    ctx.lineTo(330.5, 0.2);
    ctx.bezierCurveTo(330.6, 0.2, 330.7, 0.2, 330.9, 0.2);
    ctx.bezierCurveTo(330.9, 0.2, 330.9, 0.2, 331.0, 0.2);
    ctx.closePath();
    ctx.fill();

    // layer1/Guide

    // layer1/Guide
    ctx.restore();

    ctx.save();

    // Create our primary canvas and fill it with the pattern
    const newCanvas = document.createElement("canvas");
    newCanvas.classList.add("wizard-background");
    newCanvas.width = $(window).width();
    newCanvas.height = $(window).height();

    const newCtx = newCanvas.getContext("2d");
    const pattern = newCtx.createPattern(this.element, "repeat");
    newCtx.fillStyle = pattern;

    newCtx.fillRect(0, 0, newCanvas.width, newCanvas.height);

    // Add our primary newCanvas to the webpage
    document.body.appendChild(newCanvas);

    // hide this element
    this.element.style.display = "none";
  },
});
