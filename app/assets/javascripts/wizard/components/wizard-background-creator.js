import Component from "@ember/component";

const MAX_PARTICLES = 121;

const SIZE = 144;

let width, height;

let page = document.getElementsByTagName("html")[0];
let primaryLow = window
  .getComputedStyle(page)
  .getPropertyValue("--primary-low")
  .trim();

let primaryMed = window
  .getComputedStyle(page)
  .getPropertyValue("--primary-medium")
  .trim();

let primaryLowMid = window
  .getComputedStyle(page)
  .getPropertyValue("--primary-low-mid")
  .trim();

const COLORS = [primaryLow, primaryMed, primaryLowMid];

class Particle {
  constructor() {
    this.reset();
  }

  reset() {
    this.origX = Math.random() * (width + SIZE);
    this.speed = 1 + Math.random();
    this.ang = Math.random() * 2 * Math.PI;
    this.scale = Math.random() * 1;
    this.radius = Math.random() * 25 + 25;
    this.color = COLORS[Math.floor(Math.random() * COLORS.length)];
    this.flipped = Math.random() > 0.5 ? 1 : -1;
  }
}

export default Component.extend({
  classNames: ["wizard-background-creator"],
  tagName: "canvas",
  ctx: null,
  ready: false,
  particles: null,

  didInsertElement() {
    this._super(...arguments);

    const canvas = this.element;
    this.ctx = canvas.getContext("2d");
    this.resized();

    this.particles = [];
    for (let i = 0; i < MAX_PARTICLES; i++) {
      this.particles.push(new Particle());
    }

    this.ready = true;
    this.paint();

    $(window).on("resize.wizard", () => this.resized());
  },

  willDestroyElement() {
    this._super(...arguments);
    $(window).off("resize.wizard");
  },

  resized() {
    width = $(window).width();
    height = $(window).height();

    const canvas = this.element;
    canvas.width = 414;
    canvas.height = 414;
  },

  paint() {
    if (this.isDestroying || this.isDestroyed || !this.ready) {
      return;
    }

    const { ctx } = this;
    ctx.clearRect(0, 0, width, height);

    // this.particles.forEach((particle) => {
    //   this.drawParticle(particle);
    // });

    this.drawParticle();
  },

  drawParticle() {
    let ctx = this.ctx;
    ctx.save();
    ctx.strokeStyle = "rgba(0,0,0,0)";
    ctx.miterLimit = 4;
    ctx.font =
      "normal normal normal normal 15px/21px 'Helvetica Neue', Helvetica, Arial, sans-serif";
    ctx.font = "   15px 'HelveticaNeue',Helvetica,Arial,sans-serif";
    ctx.scale(1, 1);
    ctx.save();

    ctx.save();
    let fillColor = COLORS[Math.floor(Math.random() * COLORS.length)];
    ctx.fillStyle = fillColor;
    ctx.translate(0, -7.48);
    ctx.beginPath();
    ctx.moveTo(162.26, 198.54);
    ctx.translate(162.27837912177034, 196.98010827046136);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.56, 1.5825780876781586, 2.042145980102254, 0);
    ctx.rotate(0);
    ctx.translate(-162.27837912177034, -196.98010827046136);
    ctx.translate(162.24465673670036, 197.05271556312812);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.48, 2.0441223440466474, 3.3269189704337183, 0);
    ctx.rotate(0);
    ctx.translate(-162.24465673670036, -197.05271556312812);
    ctx.lineTo(163.31, 182.47);
    ctx.translate(162.38858867048265, 182.28398612461152);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.94, 0.1992019255118307, -0.8626359291175305, 1);
    ctx.rotate(0);
    ctx.translate(-162.38858867048265, -182.28398612461152);
    ctx.bezierCurveTo(
      162.71,
      181.32999999999998,
      162.38,
      181.07999999999998,
      162,
      180.81
    );
    ctx.bezierCurveTo(159.4, 178.81, 155.47, 175.81, 155.47, 167.5);
    ctx.bezierCurveTo(155.47, 155.15, 170.1, 149.88, 172.31, 149.5);
    ctx.bezierCurveTo(
      188.17000000000002,
      146.86,
      200.59,
      150.33,
      209.21,
      159.82
    );
    ctx.bezierCurveTo(
      209.98000000000002,
      160.67,
      216.62,
      168.38,
      212.38,
      177.89999999999998
    );
    ctx.bezierCurveTo(
      207.67,
      188.51,
      195.74,
      193.26999999999998,
      186.38,
      192.48999999999998
    );
    ctx.translate(188.87715248575336, 165.87689928882963);
    ctx.rotate(0);
    ctx.arc(0, 0, 26.73, 1.6643540956679288, 2.1805409899597996, 0);
    ctx.rotate(0);
    ctx.translate(-188.87715248575336, -165.87689928882963);
    ctx.lineTo(163.26999999999998, 198.09);
    ctx.translate(162.2194604639367, 197.09056681905795);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.45, 0.7604730652215429, 1.5428343824349193, 0);
    ctx.rotate(0);
    ctx.translate(-162.2194604639367, -197.09056681905795);
    ctx.closePath();
    ctx.moveTo(182.12, 150.66);
    ctx.translate(182.34320152777462, 207.52956199126206);
    ctx.rotate(0);
    ctx.arc(0, 0, 56.87, -1.574721104371895, -1.7418990381546988, 1);
    ctx.rotate(0);
    ctx.translate(-182.34320152777462, -207.52956199126206);
    ctx.bezierCurveTo(172.51, 151.49, 157.5, 155.87, 157.5, 167.49);
    ctx.bezierCurveTo(157.5, 174.84, 160.82, 177.37, 163.25, 179.21);
    ctx.bezierCurveTo(163.62, 179.5, 163.98, 179.77, 164.25, 180.03);
    ctx.translate(162.29153303495312, 182.30253320037795);
    ctx.rotate(0);
    ctx.arc(0, 0, 3, -0.8594920611236457, 0.16659176305728607, 0);
    ctx.rotate(0);
    ctx.translate(-162.29153303495312, -182.30253320037795);
    ctx.lineTo(163, 195.55);
    ctx.lineTo(172.34, 186.21);
    ctx.translate(173.53885141352873, 187.41530298609115);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.7, -2.3535109865550146, -0.96275142438044, 0);
    ctx.rotate(0);
    ctx.translate(-173.53885141352873, -187.41530298609115);
    ctx.translate(188.8570903495644, 165.90172227795242);
    ctx.rotate(0);
    ctx.arc(0, 0, 24.71, 2.190284834475443, 1.6659251851305492, 1);
    ctx.rotate(0);
    ctx.translate(-188.8570903495644, -165.90172227795242);
    ctx.bezierCurveTo(195.16, 191.23, 206.18, 186.85, 210.51, 177.09);
    ctx.bezierCurveTo(
      214.22,
      168.73000000000002,
      208.35999999999999,
      161.92000000000002,
      207.67999999999998,
      161.17000000000002
    );
    ctx.bezierCurveTo(201.4, 154.18, 192.8, 150.66, 182.12, 150.66);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();

    ctx.fillStyle = fillColor;
    ctx.beginPath();
    ctx.arc(169, 161.52, 2, 0, 6.283185307179586, false);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;
    ctx.beginPath();
    ctx.arc(184, 164.52, 2, 0, 6.283185307179586, false);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.beginPath();
    ctx.arc(198, 166.52, 2, 0, 6.283185307179586, false);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.restore();
    ctx.save();

    ctx.save();

    fillColor = COLORS[Math.floor(Math.random() * COLORS.length)];
    ctx.fillStyle = fillColor;
    ctx.translate(0, -7.48);
    ctx.beginPath();
    ctx.moveTo(206.26, 270.54);
    ctx.translate(206.2783791217704, 268.9801082704614);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.56, 1.5825780876781952, 2.042145980102295, 0);
    ctx.rotate(0);
    ctx.translate(-206.2783791217704, -268.9801082704614);
    ctx.translate(206.24465673670036, 269.0527155631282);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.48, 2.044122344046651, 3.3269189704337006, 0);
    ctx.rotate(0);
    ctx.translate(-206.24465673670036, -269.0527155631282);
    ctx.lineTo(207.31, 254.47000000000003);
    ctx.translate(206.3234706462743, 254.30641566628333);
    ctx.rotate(0);
    ctx.arc(0, 0, 1, 0.16432284343352815, -0.8277568470392271, 1);
    ctx.rotate(0);
    ctx.translate(-206.3234706462743, -254.30641566628333);
    ctx.bezierCurveTo(206.71, 253.33, 206.38, 253.08, 206, 252.81000000000003);
    ctx.bezierCurveTo(
      203.4,
      250.81000000000003,
      199.47,
      247.81000000000003,
      199.47,
      239.50000000000003
    );
    ctx.bezierCurveTo(
      199.47,
      227.15000000000003,
      214.1,
      221.88000000000002,
      216.31,
      221.50000000000003
    );
    ctx.bezierCurveTo(
      232.16,
      218.86000000000004,
      244.58,
      222.33000000000004,
      253.21,
      231.82000000000002
    );
    ctx.bezierCurveTo(
      253.98000000000002,
      232.66000000000003,
      260.62,
      240.37000000000003,
      256.38,
      249.90000000000003
    );
    ctx.bezierCurveTo(
      251.67,
      260.51000000000005,
      239.72,
      265.27000000000004,
      230.38,
      264.49
    );
    ctx.translate(232.87715248575336, 237.87689928882963);
    ctx.rotate(0);
    ctx.arc(0, 0, 26.73, 1.6643540956679288, 2.1805409899597996, 0);
    ctx.rotate(0);
    ctx.translate(-232.87715248575336, -237.87689928882963);
    ctx.lineTo(207.26999999999998, 270.09000000000003);
    ctx.translate(206.2194604639367, 269.090566819058);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.45, 0.7604730652215429, 1.5428343824349193, 0);
    ctx.rotate(0);
    ctx.translate(-206.2194604639367, -269.090566819058);
    ctx.closePath();
    ctx.moveTo(226.12, 222.66000000000003);
    ctx.translate(226.34320152777462, 279.5295619912621);
    ctx.rotate(0);
    ctx.arc(0, 0, 56.87, -1.574721104371895, -1.7418990381546988, 1);
    ctx.rotate(0);
    ctx.translate(-226.34320152777462, -279.5295619912621);
    ctx.bezierCurveTo(
      216.51,
      223.49000000000004,
      201.5,
      227.87000000000003,
      201.5,
      239.49000000000004
    );
    ctx.bezierCurveTo(
      201.5,
      246.84000000000003,
      204.82,
      249.37000000000003,
      207.25,
      251.21000000000004
    );
    ctx.bezierCurveTo(
      207.62,
      251.50000000000003,
      207.98,
      251.77000000000004,
      208.25,
      252.03000000000003
    );
    ctx.translate(206.29153303495312, 254.30253320037795);
    ctx.rotate(0);
    ctx.arc(0, 0, 3, -0.8594920611236457, 0.16659176305728607, 0);
    ctx.rotate(0);
    ctx.translate(-206.29153303495312, -254.30253320037795);
    ctx.lineTo(207, 267.55);
    ctx.lineTo(216.34, 258.21000000000004);
    ctx.translate(217.53885141352873, 259.41530298609115);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.7, -2.3535109865550146, -0.96275142438044, 0);
    ctx.rotate(0);
    ctx.translate(-217.53885141352873, -259.41530298609115);
    ctx.translate(232.85709034956443, 237.9017222779525);
    ctx.rotate(0);
    ctx.arc(0, 0, 24.71, 2.1902848344754453, 1.6659251851305505, 1);
    ctx.rotate(0);
    ctx.translate(-232.85709034956443, -237.9017222779525);
    ctx.bezierCurveTo(
      239.16,
      263.2200000000001,
      250.18,
      258.8500000000001,
      254.51,
      249.09000000000006
    );
    ctx.bezierCurveTo(
      258.21999999999997,
      240.73000000000008,
      252.35999999999999,
      233.92000000000007,
      251.67999999999998,
      233.17000000000007
    );
    ctx.bezierCurveTo(245.4, 226.18, 236.8, 222.66, 226.12, 222.66);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.beginPath();
    ctx.arc(213, 233.52, 2, 0, 6.283185307179586, false);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.beginPath();
    ctx.arc(228, 236.52, 2, 0, 6.283185307179586, false);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.beginPath();
    ctx.arc(242, 238.52, 2, 0, 6.283185307179586, false);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.restore();
    ctx.save();

    ctx.save();

    fillColor = COLORS[Math.floor(Math.random() * COLORS.length)];
    ctx.fillStyle = fillColor;
    ctx.translate(0, -7.48);
    ctx.beginPath();
    ctx.moveTo(93.26, 237.54);
    ctx.translate(93.27837912177037, 235.98010827046136);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.56, 1.5825780876781586, 2.042145980102254, 0);
    ctx.rotate(0);
    ctx.translate(-93.27837912177037, -235.98010827046136);
    ctx.translate(93.24465673670035, 236.05271556312812);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.48, 2.0441223440466474, 3.3269189704337183, 0);
    ctx.rotate(0);
    ctx.translate(-93.24465673670035, -236.05271556312812);
    ctx.lineTo(94.31, 221.47);
    ctx.translate(93.32347064627429, 221.30641566628327);
    ctx.rotate(0);
    ctx.arc(0, 0, 1, 0.16432284343352815, -0.8277568470392271, 1);
    ctx.rotate(0);
    ctx.translate(-93.32347064627429, -221.30641566628327);
    ctx.bezierCurveTo(
      93.71,
      220.32999999999998,
      93.38,
      220.07999999999998,
      93,
      219.81
    );
    ctx.bezierCurveTo(90.4, 217.81, 86.47, 214.81, 86.47, 206.5);
    ctx.bezierCurveTo(86.47, 194.15, 101.1, 188.88, 103.31, 188.5);
    ctx.bezierCurveTo(119.17, 185.86, 131.59, 189.33, 140.21, 198.82);
    ctx.bezierCurveTo(
      140.98000000000002,
      199.67,
      147.62,
      207.38,
      143.38,
      216.89999999999998
    );
    ctx.bezierCurveTo(
      138.67,
      227.51,
      126.74,
      232.27999999999997,
      117.38,
      231.48999999999998
    );
    ctx.translate(119.87715248575334, 204.87689928882963);
    ctx.rotate(0);
    ctx.arc(0, 0, 26.73, 1.6643540956679288, 2.1805409899597996, 0);
    ctx.rotate(0);
    ctx.translate(-119.87715248575334, -204.87689928882963);
    ctx.lineTo(94.27, 237.09);
    ctx.translate(93.21946046393671, 236.09056681905795);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.45, 0.7604730652215429, 1.5428343824349193, 0);
    ctx.rotate(0);
    ctx.translate(-93.21946046393671, -236.09056681905795);
    ctx.closePath();
    ctx.moveTo(113.12, 189.66);
    ctx.translate(113.34320152777465, 246.52956199126206);
    ctx.rotate(0);
    ctx.arc(0, 0, 56.87, -1.574721104371895, -1.7418990381546988, 1);
    ctx.rotate(0);
    ctx.translate(-113.34320152777465, -246.52956199126206);
    ctx.bezierCurveTo(103.50999999999999, 190.49, 88.5, 194.87, 88.5, 206.49);
    ctx.bezierCurveTo(88.5, 213.84, 91.82, 216.37, 94.25, 218.21);
    ctx.bezierCurveTo(94.62, 218.5, 94.98, 218.77, 95.25, 219.03);
    ctx.translate(93.2915330349531, 221.30253320037795);
    ctx.rotate(0);
    ctx.arc(0, 0, 3, -0.8594920611236457, 0.16659176305728607, 0);
    ctx.rotate(0);
    ctx.translate(-93.2915330349531, -221.30253320037795);
    ctx.lineTo(94, 234.55);
    ctx.lineTo(103.34, 225.21);
    ctx.translate(104.53885141352873, 226.41530298609115);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.7, -2.3535109865550194, -0.962751424380434, 0);
    ctx.rotate(0);
    ctx.translate(-104.53885141352873, -226.41530298609115);
    ctx.translate(119.85709034956442, 204.90172227795242);
    ctx.rotate(0);
    ctx.arc(0, 0, 24.71, 2.190284834475443, 1.6659251851305492, 1);
    ctx.rotate(0);
    ctx.translate(-119.85709034956442, -204.90172227795242);
    ctx.bezierCurveTo(126.15, 230.22, 137.18, 225.85, 141.51, 216.09);
    ctx.bezierCurveTo(
      145.22,
      207.73000000000002,
      139.35999999999999,
      200.92000000000002,
      138.67999999999998,
      200.17000000000002
    );
    ctx.bezierCurveTo(132.4, 193.18, 123.8, 189.66, 113.12, 189.66);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.beginPath();
    ctx.arc(100, 200.52, 2, 0, 6.283185307179586, false);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.beginPath();
    ctx.arc(115, 203.52, 2, 0, 6.283185307179586, false);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.beginPath();
    ctx.arc(129, 205.52, 2, 0, 6.283185307179586, false);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.restore();
    ctx.save();

    ctx.save();

    fillColor = COLORS[Math.floor(Math.random() * COLORS.length)];
    ctx.fillStyle = fillColor;
    ctx.translate(0, -7.48);
    ctx.beginPath();
    ctx.moveTo(320.26, 300.54);
    ctx.translate(320.2783791217704, 298.9801082704614);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.56, 1.5825780876781952, 2.042145980102295, 0);
    ctx.rotate(0);
    ctx.translate(-320.2783791217704, -298.9801082704614);
    ctx.translate(320.2446567367004, 299.0527155631282);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.48, 2.0441223440466705, 3.3269189704337094, 0);
    ctx.rotate(0);
    ctx.translate(-320.2446567367004, -299.0527155631282);
    ctx.lineTo(321.31, 284.47);
    ctx.translate(320.32347064627425, 284.3064156662833);
    ctx.rotate(0);
    ctx.arc(0, 0, 1, 0.16432284343350306, -0.8277568470392216, 1);
    ctx.rotate(0);
    ctx.translate(-320.32347064627425, -284.3064156662833);
    ctx.bezierCurveTo(
      320.71,
      283.33000000000004,
      320.38,
      283.08000000000004,
      320,
      282.81000000000006
    );
    ctx.bezierCurveTo(
      317.4,
      280.81000000000006,
      313.47,
      277.81000000000006,
      313.47,
      269.50000000000006
    );
    ctx.bezierCurveTo(
      313.47,
      257.15000000000003,
      328.1,
      251.88000000000005,
      330.31,
      251.50000000000006
    );
    ctx.bezierCurveTo(
      346.17,
      248.86000000000007,
      358.58,
      252.33000000000007,
      367.21,
      261.82000000000005
    );
    ctx.bezierCurveTo(
      367.97999999999996,
      262.66,
      374.62,
      270.37000000000006,
      370.38,
      279.90000000000003
    );
    ctx.bezierCurveTo(
      365.67,
      290.51000000000005,
      353.71999999999997,
      295.28000000000003,
      344.38,
      294.49
    );
    ctx.translate(346.87715248575336, 267.87689928882963);
    ctx.rotate(0);
    ctx.arc(0, 0, 26.73, 1.6643540956679288, 2.1805409899597996, 0);
    ctx.rotate(0);
    ctx.translate(-346.87715248575336, -267.87689928882963);
    ctx.lineTo(321.28, 300.09000000000003);
    ctx.translate(320.2122494133828, 299.05076533700105);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.49, 0.7718649966430601, 1.5387434650649572, 0);
    ctx.rotate(0);
    ctx.translate(-320.2122494133828, -299.05076533700105);
    ctx.closePath();
    ctx.moveTo(340.12, 252.66000000000003);
    ctx.translate(340.3432015277746, 309.5295619912621);
    ctx.rotate(0);
    ctx.arc(0, 0, 56.87, -1.5747211043718954, -1.7418990381546993, 1);
    ctx.rotate(0);
    ctx.translate(-340.3432015277746, -309.5295619912621);
    ctx.bezierCurveTo(
      330.51000000000005,
      253.49000000000004,
      315.5,
      257.87000000000006,
      315.5,
      269.49
    );
    ctx.bezierCurveTo(
      315.5,
      276.84000000000003,
      318.82,
      279.37,
      321.25,
      281.21000000000004
    );
    ctx.bezierCurveTo(
      321.62,
      281.50000000000006,
      321.98,
      281.77000000000004,
      322.25,
      282.03000000000003
    );
    ctx.translate(320.2915330349531, 284.302533200378);
    ctx.rotate(0);
    ctx.arc(0, 0, 3, -0.859492061123644, 0.16659176305727785, 0);
    ctx.rotate(0);
    ctx.translate(-320.2915330349531, -284.302533200378);
    ctx.lineTo(321, 297.55);
    ctx.lineTo(330.34, 288.21000000000004);
    ctx.translate(331.5388514135287, 289.41530298609115);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.7, -2.3535109865550243, -0.962751424380428, 0);
    ctx.rotate(0);
    ctx.translate(-331.5388514135287, -289.41530298609115);
    ctx.translate(346.85709034956443, 267.9017222779525);
    ctx.rotate(0);
    ctx.arc(0, 0, 24.71, 2.1902848344754453, 1.6659251851305505, 1);
    ctx.rotate(0);
    ctx.translate(-346.85709034956443, -267.9017222779525);
    ctx.bezierCurveTo(
      353.15999999999997,
      293.2200000000001,
      364.18,
      288.8500000000001,
      368.51,
      279.09000000000003
    );
    ctx.bezierCurveTo(
      372.21999999999997,
      270.73,
      366.36,
      263.92,
      365.68,
      263.17
    );
    ctx.bezierCurveTo(359.4, 256.18, 350.8, 252.66, 340.12, 252.66);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.beginPath();
    ctx.arc(327, 263.52, 2, 0, 6.283185307179586, false);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.beginPath();
    ctx.arc(342, 266.52, 2, 0, 6.283185307179586, false);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.beginPath();
    ctx.arc(356, 268.52, 2, 0, 6.283185307179586, false);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.restore();
    ctx.save();

    ctx.save();

    fillColor = COLORS[Math.floor(Math.random() * COLORS.length)];
    ctx.fillStyle = fillColor;

    ctx.translate(0, -7.48);
    ctx.beginPath();
    ctx.moveTo(355.26, 193.54);
    ctx.translate(355.27837912177034, 191.98010827046136);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.56, 1.5825780876781586, 2.042145980102254, 0);
    ctx.rotate(0);
    ctx.translate(-355.27837912177034, -191.98010827046136);
    ctx.translate(355.25584057090396, 192.04722915389618);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.49, 2.0491245632535886, 3.321916751226806, 0);
    ctx.rotate(0);
    ctx.translate(-355.25584057090396, -192.04722915389618);
    ctx.lineTo(356.31, 177.47);
    ctx.translate(355.3885886704826, 177.28398612461152);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.94, 0.1992019255118307, -0.8626359291175305, 1);
    ctx.rotate(0);
    ctx.translate(-355.3885886704826, -177.28398612461152);
    ctx.bezierCurveTo(
      355.71,
      176.32999999999998,
      355.38,
      176.07999999999998,
      355,
      175.81
    );
    ctx.bezierCurveTo(352.4, 173.81, 348.47, 170.81, 348.47, 162.5);
    ctx.bezierCurveTo(348.47, 150.15, 363.1, 144.88, 365.31, 144.5);
    ctx.bezierCurveTo(381.17, 141.86, 393.58, 145.33, 402.21, 154.82);
    ctx.bezierCurveTo(
      402.97999999999996,
      155.67,
      409.62,
      163.38,
      405.38,
      172.89999999999998
    );
    ctx.bezierCurveTo(
      400.67,
      183.51,
      388.71999999999997,
      188.26999999999998,
      379.38,
      187.48999999999998
    );
    ctx.translate(381.87715248575336, 160.87689928882963);
    ctx.rotate(0);
    ctx.arc(0, 0, 26.73, 1.6643540956679288, 2.1805409899597996, 0);
    ctx.rotate(0);
    ctx.translate(-381.87715248575336, -160.87689928882963);
    ctx.lineTo(356.28, 193.09);
    ctx.translate(355.2122494133828, 192.050765337001);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.49, 0.7718649966430601, 1.5387434650649572, 0);
    ctx.rotate(0);
    ctx.translate(-355.2122494133828, -192.050765337001);
    ctx.closePath();
    ctx.moveTo(375.12, 145.66);
    ctx.translate(375.3432015277746, 202.52956199126206);
    ctx.rotate(0);
    ctx.arc(0, 0, 56.87, -1.5747211043718954, -1.7418990381546993, 1);
    ctx.rotate(0);
    ctx.translate(-375.3432015277746, -202.52956199126206);
    ctx.bezierCurveTo(365.51000000000005, 146.49, 350.5, 150.87, 350.5, 162.49);
    ctx.bezierCurveTo(350.5, 169.84, 353.82, 172.37, 356.25, 174.21);
    ctx.bezierCurveTo(356.62, 174.5, 356.98, 174.77, 357.25, 175.03);
    ctx.translate(355.2915330349531, 177.30253320037795);
    ctx.rotate(0);
    ctx.arc(0, 0, 3, -0.8594920611236457, 0.16659176305728607, 0);
    ctx.rotate(0);
    ctx.translate(-355.2915330349531, -177.30253320037795);
    ctx.lineTo(356, 190.55);
    ctx.lineTo(365.34, 181.21);
    ctx.translate(366.5388514135287, 182.41530298609112);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.7, -2.3535109865550243, -0.962751424380428, 0);
    ctx.rotate(0);
    ctx.translate(-366.5388514135287, -182.41530298609112);
    ctx.translate(381.8570903495644, 160.90172227795242);
    ctx.rotate(0);
    ctx.arc(0, 0, 24.71, 2.190284834475443, 1.6659251851305492, 1);
    ctx.rotate(0);
    ctx.translate(-381.8570903495644, -160.90172227795242);
    ctx.bezierCurveTo(388.17, 186.23, 399.18, 181.85, 403.51, 172.09);
    ctx.bezierCurveTo(
      407.21999999999997,
      163.73000000000002,
      401.36,
      156.92000000000002,
      400.68,
      156.17000000000002
    );
    ctx.bezierCurveTo(394.4, 149.18, 385.8, 145.66, 375.12, 145.66);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.beginPath();
    ctx.arc(362, 156.52, 2, 0, 6.283185307179586, false);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.beginPath();
    ctx.arc(377, 159.52, 2, 0, 6.283185307179586, false);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.beginPath();
    ctx.arc(391, 161.52, 2, 0, 6.283185307179586, false);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.restore();
    ctx.save();

    ctx.save();
    fillColor = COLORS[Math.floor(Math.random() * COLORS.length)];

    ctx.fillStyle = fillColor;

    ctx.translate(0, -7.48);
    ctx.beginPath();
    ctx.moveTo(289.26, 124.54);
    ctx.translate(289.27837912177034, 122.9801082704614);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.56, 1.5825780876781768, 2.0421459801022745, 0);
    ctx.rotate(0);
    ctx.translate(-289.27837912177034, -122.9801082704614);
    ctx.translate(289.25584057090396, 123.04722915389621);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.49, 2.0491245632535886, 3.321916751226806, 0);
    ctx.rotate(0);
    ctx.translate(-289.25584057090396, -123.04722915389621);
    ctx.lineTo(290.31, 108.47);
    ctx.translate(289.3885886704826, 108.28398612461153);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.94, 0.1992019255118307, -0.8626359291175305, 1);
    ctx.rotate(0);
    ctx.translate(-289.3885886704826, -108.28398612461153);
    ctx.bezierCurveTo(289.71, 107.33, 289.38, 107.08, 289, 106.80999999999999);
    ctx.bezierCurveTo(
      286.4,
      104.80999999999999,
      282.47,
      101.80999999999999,
      282.47,
      93.49999999999999
    );
    ctx.bezierCurveTo(
      282.47,
      81.14999999999999,
      297.1,
      75.87999999999998,
      299.31,
      75.49999999999999
    );
    ctx.bezierCurveTo(
      315.17,
      72.85999999999999,
      327.58,
      76.32999999999998,
      336.21,
      85.82
    );
    ctx.bezierCurveTo(
      336.97999999999996,
      86.66999999999999,
      343.62,
      94.38,
      339.38,
      103.89999999999999
    );
    ctx.bezierCurveTo(
      334.67,
      114.50999999999999,
      322.71999999999997,
      119.27,
      313.38,
      118.49
    );
    ctx.translate(315.8771524857534, 91.87689928882963);
    ctx.rotate(0);
    ctx.arc(0, 0, 26.73, 1.6643540956679297, 2.1805409899598005, 0);
    ctx.rotate(0);
    ctx.translate(-315.8771524857534, -91.87689928882963);
    ctx.lineTo(290.28, 124.08999999999999);
    ctx.translate(289.2122494133828, 123.05076533700102);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.49, 0.7718649966430324, 1.5387434650649379, 0);
    ctx.rotate(0);
    ctx.translate(-289.2122494133828, -123.05076533700102);
    ctx.closePath();
    ctx.moveTo(309.12, 76.66);
    ctx.translate(309.34320152777457, 133.52956199126206);
    ctx.rotate(0);
    ctx.arc(0, 0, 56.87, -1.5747211043718938, -1.7418990381546977, 1);
    ctx.rotate(0);
    ctx.translate(-309.34320152777457, -133.52956199126206);
    ctx.bezierCurveTo(
      299.51000000000005,
      77.49,
      284.5,
      81.86999999999999,
      284.5,
      93.49
    );
    ctx.bezierCurveTo(
      284.5,
      100.83999999999999,
      287.82,
      103.36999999999999,
      290.25,
      105.21
    );
    ctx.bezierCurveTo(
      290.62,
      105.5,
      290.98,
      105.77,
      291.25,
      106.02999999999999
    );
    ctx.translate(289.2915330349531, 108.30253320037794);
    ctx.rotate(0);
    ctx.arc(0, 0, 3, -0.8594920611236446, 0.16659176305728207, 0);
    ctx.rotate(0);
    ctx.translate(-289.2915330349531, -108.30253320037794);
    ctx.lineTo(290, 121.55);
    ctx.lineTo(299.34, 112.21);
    ctx.translate(300.5388514135287, 113.41530298609112);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.7, -2.3535109865550243, -0.962751424380428, 0);
    ctx.rotate(0);
    ctx.translate(-300.5388514135287, -113.41530298609112);
    ctx.translate(315.85709034956443, 91.90172227795243);
    ctx.rotate(0);
    ctx.arc(0, 0, 24.71, 2.1902848344754444, 1.66592518513055, 1);
    ctx.rotate(0);
    ctx.translate(-315.85709034956443, -91.90172227795243);
    ctx.bezierCurveTo(322.17, 117.23, 333.18, 112.85, 337.51, 103.09);
    ctx.bezierCurveTo(341.21999999999997, 94.73, 335.36, 87.92, 334.68, 87.17);
    ctx.bezierCurveTo(328.4, 80.18, 319.8, 76.66, 309.12, 76.66);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.beginPath();
    ctx.arc(296, 87.52, 2, 0, 6.283185307179586, false);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.beginPath();
    ctx.arc(311, 90.52, 2, 0, 6.283185307179586, false);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.beginPath();
    ctx.arc(325, 92.52, 2, 0, 6.283185307179586, false);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.restore();
    ctx.save();

    ctx.save();
    fillColor = COLORS[Math.floor(Math.random() * COLORS.length)];
    ctx.fillStyle = fillColor;

    ctx.translate(0, -7.48);
    ctx.beginPath();
    ctx.moveTo(232.23, 164.36);
    ctx.translate(232.22946657928054, 163.47000015985267);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.89, 1.5701969776360447, 2.571956532403446, 0);
    ctx.rotate(0);
    ctx.translate(-232.22946657928054, -163.47000015985267);
    ctx.lineTo(225.34, 154.41000000000003);
    ctx.translate(217.74576571086828, 134.70098394956077);
    ctx.rotate(0);
    ctx.arc(0, 0, 21.1, 1.2056641989451677, 1.7156514642216292, 0);
    ctx.rotate(0);
    ctx.translate(-217.74576571086828, -134.70098394956077);
    ctx.bezierCurveTo(
      207.57,
      154.48000000000002,
      199.45,
      148.93,
      197.7,
      140.44
    );
    ctx.bezierCurveTo(
      196.17,
      132.87,
      202.42999999999998,
      128.51,
      203.14,
      128.04
    );
    ctx.bezierCurveTo(
      211.26,
      122.72,
      221.14,
      122.42999999999999,
      232.67999999999998,
      127.17999999999999
    );
    ctx.bezierCurveTo(
      234.18999999999997,
      127.80999999999999,
      244.24999999999997,
      134.35,
      242.17999999999998,
      143.07
    );
    ctx.bezierCurveTo(
      240.74999999999997,
      149.07,
      237.31999999999996,
      150.5,
      235.04999999999998,
      151.45999999999998
    );
    ctx.lineTo(234.17, 151.83999999999997);
    ctx.translate(234.63641801297, 152.72456443359263);
    ctx.rotate(0);
    ctx.arc(0, 0, 1, -2.0560333252728094, -3.056927105537934, 1);
    ctx.rotate(0);
    ctx.translate(-234.63641801297, -152.72456443359263);
    ctx.lineTo(233.07, 163.55999999999997);
    ctx.translate(232.21113929079615, 163.51574751774365);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.86, 0.05147910915724974, 1.3254819620489395, 0);
    ctx.rotate(0);
    ctx.translate(-232.21113929079615, -163.51574751774365);
    ctx.translate(232.27743353007847, 163.4512370714954);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.91, 1.413481812593808, 1.6229447177735994, 0);
    ctx.rotate(0);
    ctx.translate(-232.27743353007847, -163.4512370714954);
    ctx.closePath();
    ctx.moveTo(225.29, 153.36);
    ctx.translate(225.32545137852796, 154.35937140231275);
    ctx.rotate(0);
    ctx.arc(0, 0, 1, -1.6062551354093, -0.546115195812924, 0);
    ctx.rotate(0);
    ctx.translate(-225.32545137852796, -154.35937140231275);
    ctx.lineTo(226.17999999999998, 153.84);
    ctx.lineTo(232.12999999999997, 163.09);
    ctx.lineTo(232.67999999999998, 152.54);
    ctx.translate(234.60773434415958, 152.63348956277304);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.93, -3.09313350183259, -2.0140465982518734, 0);
    ctx.rotate(0);
    ctx.translate(-234.60773434415958, -152.63348956277304);
    ctx.lineTo(234.69999999999996, 150.48999999999998);
    ctx.bezierCurveTo(
      236.90999999999997,
      149.55999999999997,
      239.93999999999997,
      148.27999999999997,
      241.23999999999995,
      142.79
    );
    ctx.bezierCurveTo(
      243.15999999999994,
      134.73,
      233.74999999999994,
      128.64,
      232.33999999999995,
      128.06
    );
    ctx.bezierCurveTo(
      221.17999999999995,
      123.44,
      211.54999999999995,
      123.7,
      203.72999999999996,
      128.83
    );
    ctx.bezierCurveTo(
      203.06999999999996,
      129.26000000000002,
      197.31999999999996,
      133.26000000000002,
      198.72999999999996,
      140.19
    );
    ctx.bezierCurveTo(
      200.34999999999997,
      148.19,
      208.07999999999996,
      153.5,
      214.86999999999995,
      154.54
    );
    ctx.translate(217.759059510289, 134.74976667277497);
    ctx.rotate(0);
    ctx.arc(0, 0, 20, 1.7157564542878285, 1.2040853615868894, 1);
    ctx.rotate(0);
    ctx.translate(-217.759059510289, -134.74976667277497);
    ctx.translate(225.21187805421692, 154.62753665060353);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.24, -1.8001221119841384, -1.5077530053825252, 0);
    ctx.rotate(0);
    ctx.translate(-225.21187805421692, -154.62753665060353);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.translate(40.41, 327.22);
    ctx.rotate(-1.3374458058032546);
    ctx.beginPath();
    ctx.moveTo(233.48, 141.78);
    ctx.bezierCurveTo(
      233.48,
      142.64156420973603,
      232.80842712474617,
      143.34,
      231.98,
      143.34
    );
    ctx.bezierCurveTo(
      231.1515728752538,
      143.34,
      230.48,
      142.64156420973603,
      230.48,
      141.78
    );
    ctx.bezierCurveTo(
      230.48,
      140.91843579026397,
      231.1515728752538,
      140.22,
      231.98,
      140.22
    );
    ctx.bezierCurveTo(
      232.80842712474617,
      140.22,
      233.48,
      140.91843579026397,
      233.48,
      141.78
    );
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.translate(31.75, 315.24);
    ctx.rotate(-1.3374458058032546);
    ctx.beginPath();
    ctx.moveTo(221.57, 141.27);
    ctx.bezierCurveTo(
      221.57,
      142.13156420973604,
      220.89842712474618,
      142.83,
      220.07,
      142.83
    );
    ctx.bezierCurveTo(
      219.2415728752538,
      142.83,
      218.57,
      142.13156420973604,
      218.57,
      141.27
    );
    ctx.bezierCurveTo(
      218.57,
      140.40843579026398,
      219.2415728752538,
      139.71,
      220.07,
      139.71
    );
    ctx.bezierCurveTo(
      220.89842712474618,
      139.71,
      221.57,
      140.40843579026398,
      221.57,
      141.27
    );
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.translate(24.35, 303.74);
    ctx.rotate(-1.3374458058032546);
    ctx.beginPath();
    ctx.moveTo(210.59, 140.2);
    ctx.bezierCurveTo(
      210.59,
      141.06156420973602,
      209.9184271247462,
      141.76,
      209.09,
      141.76
    );
    ctx.bezierCurveTo(
      208.26157287525382,
      141.76,
      207.59,
      141.06156420973602,
      207.59,
      140.2
    );
    ctx.bezierCurveTo(
      207.59,
      139.33843579026396,
      208.26157287525382,
      138.64,
      209.09,
      138.64
    );
    ctx.bezierCurveTo(
      209.9184271247462,
      138.64,
      210.59,
      139.33843579026396,
      210.59,
      140.2
    );
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.restore();
    ctx.save();

    fillColor = COLORS[Math.floor(Math.random() * COLORS.length)];

    ctx.fillStyle = fillColor;

    ctx.translate(0, -7.48);
    ctx.beginPath();
    ctx.moveTo(134.67, 142.47);
    ctx.translate(134.67287401513676, 141.61000480231746);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.86, 1.5741382110813655, 2.5909321271391486, 0);
    ctx.rotate(0);
    ctx.translate(-134.67287401513676, -141.61000480231746);
    ctx.lineTo(128.08, 133);
    ctx.bezierCurveTo(128.08, 133, 128.08, 133, 128.08, 133);
    ctx.translate(120.88547694144577, 114.22099741839489);
    ctx.rotate(0);
    ctx.arc(0, 0, 20.11, 1.2049299310247137, 1.7157829683217227, 0);
    ctx.rotate(0);
    ctx.translate(-120.88547694144577, -114.22099741839489);
    ctx.bezierCurveTo(
      111.16000000000003,
      133.07,
      103.41000000000003,
      127.77000000000001,
      101.77000000000001,
      119.65
    );
    ctx.bezierCurveTo(
      100.30000000000001,
      112.41000000000001,
      106.29,
      108.24000000000001,
      106.98,
      107.79
    );
    ctx.bezierCurveTo(
      114.73,
      102.71000000000001,
      124.22,
      102.43,
      135.19,
      106.97000000000001
    );
    ctx.bezierCurveTo(
      136.63,
      107.57000000000001,
      146.25,
      113.82000000000001,
      144.27,
      122.17000000000002
    );
    ctx.bezierCurveTo(
      142.91,
      127.89000000000001,
      139.62,
      129.27,
      137.45000000000002,
      130.17000000000002
    );
    ctx.bezierCurveTo(
      137.15,
      130.3,
      136.87,
      130.41000000000003,
      136.62,
      130.53000000000003
    );
    ctx.translate(136.9794306927213, 131.3112871284809);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.86, -2.0019758583337, -3.1052042417507515, 1);
    ctx.rotate(0);
    ctx.translate(-136.9794306927213, -131.3112871284809);
    ctx.lineTo(135.58, 141.70000000000002);
    ctx.translate(134.71207126106756, 141.6400024655911);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.87, 0.0690174632618333, 1.5731770888917096, 0);
    ctx.rotate(0);
    ctx.translate(-134.71207126106756, -141.6400024655911);
    ctx.closePath();
    ctx.moveTo(128.92, 132.41);
    ctx.lineTo(134.55999999999997, 141.18);
    ctx.lineTo(135.07999999999998, 131.18);
    ctx.translate(136.96682250412215, 131.28954833608142);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.89, -3.0835980669113643, -2.023582033173086, 0);
    ctx.rotate(0);
    ctx.translate(-136.96682250412215, -131.28954833608142);
    ctx.lineTo(137.01999999999998, 129.21);
    ctx.bezierCurveTo(
      139.13,
      128.32000000000002,
      142.01999999999998,
      127.10000000000001,
      143.24999999999997,
      121.88000000000001
    );
    ctx.bezierCurveTo(
      145.07999999999998,
      114.19000000000001,
      136.10999999999999,
      108.39000000000001,
      134.76999999999998,
      107.88000000000001
    );
    ctx.bezierCurveTo(
      124.11999999999998,
      103.47000000000001,
      114.93999999999998,
      103.72000000000001,
      107.47999999999999,
      108.61000000000001
    );
    ctx.bezierCurveTo(
      106.85,
      109.02000000000001,
      101.36999999999999,
      112.83000000000001,
      102.71,
      119.44000000000001
    );
    ctx.bezierCurveTo(
      104.25999999999999,
      127.10000000000001,
      111.61999999999999,
      132.12,
      118.08999999999999,
      133.11
    );
    ctx.translate(120.87323494746221, 114.31495801475228);
    ctx.rotate(0);
    ctx.arc(0, 0, 19, 1.7178113878946062, 1.2038388789290857, 1);
    ctx.rotate(0);
    ctx.translate(-120.87323494746221, -114.31495801475228);
    ctx.translate(128.06911380327324, 132.97535005493472);
    ctx.rotate(0);
    ctx.arc(0, 0, 1, -1.9596347470783275, -0.5531264612881002, 0);
    ctx.rotate(0);
    ctx.translate(-128.06911380327324, -132.97535005493472);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.translate(-14.25, 216.26);
    ctx.rotate(-1.3374458058032546);
    ctx.beginPath();
    ctx.moveTo(135.86, 120.88);
    ctx.bezierCurveTo(
      135.86,
      121.70290427724788,
      135.21976719225805,
      122.36999999999999,
      134.43,
      122.36999999999999
    );
    ctx.bezierCurveTo(
      133.64023280774197,
      122.36999999999999,
      133,
      121.70290427724788,
      133,
      120.88
    );
    ctx.bezierCurveTo(
      133,
      120.05709572275211,
      133.64023280774197,
      119.39,
      134.43,
      119.39
    );
    ctx.bezierCurveTo(
      135.21976719225805,
      119.39,
      135.86,
      120.05709572275211,
      135.86,
      120.88
    );
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.translate(-22.52, 204.82);
    ctx.rotate(-1.3374458058032546);
    ctx.beginPath();
    ctx.moveTo(124.49000000000001, 120.39);
    ctx.bezierCurveTo(
      124.49000000000001,
      121.21290427724789,
      123.84976719225804,
      121.88,
      123.06,
      121.88
    );
    ctx.bezierCurveTo(
      122.27023280774196,
      121.88,
      121.63,
      121.21290427724789,
      121.63,
      120.39
    );
    ctx.bezierCurveTo(
      121.63,
      119.56709572275211,
      122.27023280774196,
      118.9,
      123.06,
      118.9
    );
    ctx.bezierCurveTo(
      123.84976719225804,
      118.9,
      124.49000000000001,
      119.56709572275211,
      124.49000000000001,
      120.39
    );
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.translate(-29.59, 193.84);
    ctx.rotate(-1.3374458058032546);
    ctx.beginPath();
    ctx.moveTo(114.01, 119.38);
    ctx.bezierCurveTo(
      114.01,
      120.20290427724788,
      113.36976719225804,
      120.86999999999999,
      112.58,
      120.86999999999999
    );
    ctx.bezierCurveTo(
      111.79023280774196,
      120.86999999999999,
      111.14999999999999,
      120.20290427724788,
      111.14999999999999,
      119.38
    );
    ctx.bezierCurveTo(
      111.14999999999999,
      118.55709572275211,
      111.79023280774196,
      117.89,
      112.58,
      117.89
    );
    ctx.bezierCurveTo(
      113.36976719225804,
      117.89,
      114.01,
      118.55709572275211,
      114.01,
      119.38
    );
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();

    ctx.save();
    fillColor = COLORS[Math.floor(Math.random() * COLORS.length)];
    ctx.fillStyle = fillColor;

    ctx.translate(0, -7.48);
    ctx.beginPath();
    ctx.moveTo(124.67, 318.46);
    ctx.translate(124.661139075547, 317.61004618712667);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.85, 1.5603715209703448, 2.5837496623625604, 0);
    ctx.rotate(0);
    ctx.translate(-124.661139075547, -317.61004618712667);
    ctx.lineTo(118.08, 309);
    ctx.lineTo(118.08, 309);
    ctx.translate(110.88547694144576, 290.2209974183949);
    ctx.rotate(0);
    ctx.arc(0, 0, 20.11, 1.2049299310247137, 1.7157829683217227, 0);
    ctx.rotate(0);
    ctx.translate(-110.88547694144576, -290.2209974183949);
    ctx.bezierCurveTo(101.16, 309.07, 93.41, 303.77, 91.77000000000001, 295.65);
    ctx.bezierCurveTo(
      90.30000000000001,
      288.40999999999997,
      96.29,
      284.23999999999995,
      96.98,
      283.78999999999996
    );
    ctx.bezierCurveTo(
      104.73,
      278.71,
      114.22,
      278.42999999999995,
      125.19,
      282.96999999999997
    );
    ctx.bezierCurveTo(
      126.63,
      283.57,
      136.25,
      289.82,
      134.27,
      298.16999999999996
    );
    ctx.bezierCurveTo(
      132.91,
      303.89,
      129.62,
      305.27,
      127.45000000000002,
      306.16999999999996
    );
    ctx.bezierCurveTo(
      127.15000000000002,
      306.28999999999996,
      126.87000000000002,
      306.40999999999997,
      126.62000000000002,
      306.53
    );
    ctx.translate(126.97943069272132, 307.31128712848084);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.86, -2.0019758583337, -3.1052042417507515, 1);
    ctx.rotate(0);
    ctx.translate(-126.97943069272132, -307.31128712848084);
    ctx.lineTo(125.58000000000001, 317.7);
    ctx.translate(124.75087797689164, 317.66183364313065);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.83, 0.04599978321422913, 1.3409192258162461, 0);
    ctx.rotate(0);
    ctx.translate(-124.75087797689164, -317.66183364313065);
    ctx.translate(124.82587634828718, 317.90133859624575);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.58, 1.3727390930995798, 1.8428937922380033, 0);
    ctx.rotate(0);
    ctx.translate(-124.82587634828718, -317.90133859624575);
    ctx.closePath();
    ctx.moveTo(118.05, 307.94);
    ctx.translate(118.07185314946574, 308.93976119141445);
    ctx.rotate(0);
    ctx.arc(0, 0, 1, -1.5926512160000696, -0.5583189754368387, 0);
    ctx.rotate(0);
    ctx.translate(-118.07185314946574, -308.93976119141445);
    ctx.lineTo(118.92, 308.41);
    ctx.lineTo(124.56, 317.18);
    ctx.lineTo(125.08, 307.18);
    ctx.translate(126.96682250412215, 307.28954833608145);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.89, -3.0835980669113487, -2.0235820331730845, 0);
    ctx.rotate(0);
    ctx.translate(-126.96682250412215, -307.28954833608145);
    ctx.lineTo(127.02, 305.21000000000004);
    ctx.bezierCurveTo(
      129.13,
      304.32000000000005,
      132.01999999999998,
      303.1,
      133.25,
      297.88000000000005
    );
    ctx.bezierCurveTo(
      135.08,
      290.20000000000005,
      126.11,
      284.39000000000004,
      124.77,
      283.88000000000005
    );
    ctx.bezierCurveTo(
      114.11999999999999,
      279.47,
      104.94,
      279.72,
      97.47999999999999,
      284.61000000000007
    );
    ctx.bezierCurveTo(
      96.85,
      285.0200000000001,
      91.38,
      288.8400000000001,
      92.71,
      295.44000000000005
    );
    ctx.bezierCurveTo(
      94.25999999999999,
      303.1000000000001,
      101.61999999999999,
      308.12000000000006,
      108.08999999999999,
      309.11000000000007
    );
    ctx.translate(110.87323494746221, 290.31495801475234);
    ctx.rotate(0);
    ctx.arc(0, 0, 19, 1.7178113878946062, 1.2038388789290857, 1);
    ctx.rotate(0);
    ctx.translate(-110.87323494746221, -290.31495801475234);
    ctx.translate(118.13315491947594, 308.85623428192076);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.92, -2.0733786391181206, -1.6613056326114104, 0);
    ctx.rotate(0);
    ctx.translate(-118.13315491947594, -308.85623428192076);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.translate(-193.18, 341.84);
    ctx.rotate(-1.3374458058032546);
    ctx.beginPath();
    ctx.moveTo(125.86000000000001, 296.88);
    ctx.bezierCurveTo(
      125.86000000000001,
      297.70290427724785,
      125.21976719225805,
      298.37,
      124.43,
      298.37
    );
    ctx.bezierCurveTo(
      123.64023280774197,
      298.37,
      123,
      297.70290427724785,
      123,
      296.88
    );
    ctx.bezierCurveTo(
      123,
      296.05709572275214,
      123.64023280774197,
      295.39,
      124.43,
      295.39
    );
    ctx.bezierCurveTo(
      125.21976719225805,
      295.39,
      125.86000000000001,
      296.05709572275214,
      125.86000000000001,
      296.88
    );
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.translate(-201.44, 330.4);
    ctx.rotate(-1.3374458058032546);
    ctx.beginPath();
    ctx.moveTo(114.49000000000001, 296.39);
    ctx.bezierCurveTo(
      114.49000000000001,
      297.21290427724784,
      113.84976719225804,
      297.88,
      113.06,
      297.88
    );
    ctx.bezierCurveTo(
      112.27023280774196,
      297.88,
      111.63,
      297.21290427724784,
      111.63,
      296.39
    );
    ctx.bezierCurveTo(
      111.63,
      295.56709572275213,
      112.27023280774196,
      294.9,
      113.06,
      294.9
    );
    ctx.bezierCurveTo(
      113.84976719225804,
      294.9,
      114.49000000000001,
      295.56709572275213,
      114.49000000000001,
      296.39
    );
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.translate(-208.51, 319.43);
    ctx.rotate(-1.3374458058032546);
    ctx.beginPath();
    ctx.moveTo(104.01, 295.38);
    ctx.bezierCurveTo(
      104.01,
      296.20290427724785,
      103.36976719225804,
      296.87,
      102.58,
      296.87
    );
    ctx.bezierCurveTo(
      101.79023280774196,
      296.87,
      101.14999999999999,
      296.20290427724785,
      101.14999999999999,
      295.38
    );
    ctx.bezierCurveTo(
      101.14999999999999,
      294.55709572275214,
      101.79023280774196,
      293.89,
      102.58,
      293.89
    );
    ctx.bezierCurveTo(
      103.36976719225804,
      293.89,
      104.01,
      294.55709572275214,
      104.01,
      295.38
    );
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.restore();
    ctx.save();

    ctx.save();
    fillColor = COLORS[Math.floor(Math.random() * COLORS.length)];
    ctx.fillStyle = fillColor;

    ctx.translate(0, -7.48);
    ctx.beginPath();
    ctx.moveTo(220.67, 346.46);
    ctx.translate(220.661139075547, 345.61004618712667);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.85, 1.5603715209703617, 2.5837496623625604, 0);
    ctx.rotate(0);
    ctx.translate(-220.661139075547, -345.61004618712667);
    ctx.lineTo(214.08, 337);
    ctx.lineTo(214.08, 337);
    ctx.translate(206.8854769414458, 318.2209974183949);
    ctx.rotate(0);
    ctx.arc(0, 0, 20.11, 1.2049299310247137, 1.7157829683217227, 0);
    ctx.rotate(0);
    ctx.translate(-206.8854769414458, -318.2209974183949);
    ctx.bezierCurveTo(
      197.16000000000003,
      337.07,
      189.41000000000003,
      331.77,
      187.77,
      323.65
    );
    ctx.bezierCurveTo(
      186.3,
      316.40999999999997,
      192.29000000000002,
      312.23999999999995,
      192.98000000000002,
      311.78999999999996
    );
    ctx.bezierCurveTo(
      200.73000000000002,
      306.71,
      210.22000000000003,
      306.42999999999995,
      221.19000000000003,
      310.96999999999997
    );
    ctx.bezierCurveTo(
      222.63000000000002,
      311.57,
      232.25000000000003,
      317.82,
      230.27000000000004,
      326.16999999999996
    );
    ctx.bezierCurveTo(
      228.91000000000003,
      331.89,
      225.62000000000003,
      333.27,
      223.45000000000005,
      334.16999999999996
    );
    ctx.bezierCurveTo(
      223.15000000000003,
      334.28999999999996,
      222.87000000000003,
      334.40999999999997,
      222.62000000000003,
      334.53
    );
    ctx.translate(222.97943069272134, 335.31128712848084);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.86, -2.0019758583337, -3.1052042417507515, 1);
    ctx.rotate(0);
    ctx.translate(-222.97943069272134, -335.31128712848084);
    ctx.lineTo(221.58000000000004, 345.7);
    ctx.translate(220.7505071644217, 345.6709890413086);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.83, 0.03496008325585802, 1.6196195337308785, 0);
    ctx.rotate(0);
    ctx.translate(-220.7505071644217, -345.6709890413086);
    ctx.closePath();
    ctx.moveTo(214.04999999999998, 335.94);
    ctx.translate(214.07185314946574, 336.93976119141445);
    ctx.rotate(0);
    ctx.arc(0, 0, 1, -1.5926512160000696, -0.5583189754368387, 0);
    ctx.rotate(0);
    ctx.translate(-214.07185314946574, -336.93976119141445);
    ctx.lineTo(220.55999999999997, 345.18);
    ctx.lineTo(221.07999999999998, 335.18);
    ctx.translate(222.94749982027315, 335.2766665468488);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.87, -3.0898762627971363, -2.017303837287303, 0);
    ctx.rotate(0);
    ctx.translate(-222.94749982027315, -335.2766665468488);
    ctx.lineTo(223.01999999999998, 333.21000000000004);
    ctx.bezierCurveTo(
      225.13,
      332.32000000000005,
      228.01999999999998,
      331.1,
      229.24999999999997,
      325.88000000000005
    );
    ctx.bezierCurveTo(
      231.07999999999998,
      318.20000000000005,
      222.10999999999999,
      312.39000000000004,
      220.76999999999998,
      311.88000000000005
    );
    ctx.bezierCurveTo(
      210.11999999999998,
      307.47,
      200.94,
      307.72,
      193.48,
      312.61000000000007
    );
    ctx.bezierCurveTo(
      192.85,
      313.0200000000001,
      187.38,
      316.8400000000001,
      188.70999999999998,
      323.44000000000005
    );
    ctx.bezierCurveTo(
      190.26,
      331.1000000000001,
      197.61999999999998,
      336.12000000000006,
      204.08999999999997,
      337.11000000000007
    );
    ctx.translate(206.8732349474622, 318.31495801475234);
    ctx.rotate(0);
    ctx.arc(0, 0, 19, 1.7178113878946062, 1.2038388789290857, 1);
    ctx.rotate(0);
    ctx.translate(-206.8732349474622, -318.31495801475234);
    ctx.translate(214.13315491947594, 336.85623428192076);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.92, -2.073378639118114, -1.6613056326113735, 0);
    ctx.rotate(0);
    ctx.translate(-214.13315491947594, -336.85623428192076);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.translate(-146.61, 456.77);
    ctx.rotate(-1.3374458058032546);
    ctx.beginPath();
    ctx.moveTo(221.86, 324.88);
    ctx.bezierCurveTo(
      221.86,
      325.70290427724785,
      221.21976719225805,
      326.37,
      220.43,
      326.37
    );
    ctx.bezierCurveTo(
      219.64023280774197,
      326.37,
      219,
      325.70290427724785,
      219,
      324.88
    );
    ctx.bezierCurveTo(
      219,
      324.05709572275214,
      219.64023280774197,
      323.39,
      220.43,
      323.39
    );
    ctx.bezierCurveTo(
      221.21976719225805,
      323.39,
      221.86,
      324.05709572275214,
      221.86,
      324.88
    );
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.translate(-154.87, 445.33);
    ctx.rotate(-1.3374458058032546);
    ctx.beginPath();
    ctx.moveTo(210.49, 324.39);
    ctx.bezierCurveTo(
      210.49,
      325.21290427724784,
      209.84976719225804,
      325.88,
      209.06,
      325.88
    );
    ctx.bezierCurveTo(
      208.27023280774196,
      325.88,
      207.63,
      325.21290427724784,
      207.63,
      324.39
    );
    ctx.bezierCurveTo(
      207.63,
      323.56709572275213,
      208.27023280774196,
      322.9,
      209.06,
      322.9
    );
    ctx.bezierCurveTo(
      209.84976719225804,
      322.9,
      210.49,
      323.56709572275213,
      210.49,
      324.39
    );
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.translate(-161.94, 434.35);
    ctx.rotate(-1.3374458058032546);
    ctx.beginPath();
    ctx.moveTo(200.01000000000002, 323.38);
    ctx.bezierCurveTo(
      200.01000000000002,
      324.20290427724785,
      199.36976719225805,
      324.87,
      198.58,
      324.87
    );
    ctx.bezierCurveTo(
      197.79023280774197,
      324.87,
      197.15,
      324.20290427724785,
      197.15,
      323.38
    );
    ctx.bezierCurveTo(
      197.15,
      322.55709572275214,
      197.79023280774197,
      321.89,
      198.58,
      321.89
    );
    ctx.bezierCurveTo(
      199.36976719225805,
      321.89,
      200.01000000000002,
      322.55709572275214,
      200.01000000000002,
      323.38
    );
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.restore();
    ctx.save();

    ctx.save();
    fillColor = COLORS[Math.floor(Math.random() * COLORS.length)];
    ctx.fillStyle = fillColor;

    ctx.translate(0, -7.48);
    ctx.beginPath();
    ctx.moveTo(319.67, 399.46);
    ctx.translate(319.66891853298245, 398.60000067998334);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.86, 1.5695388066755815, 2.6045151881377295, 0);
    ctx.rotate(0);
    ctx.translate(-319.66891853298245, -398.60000067998334);
    ctx.lineTo(313.07, 389.39);
    ctx.bezierCurveTo(313.07, 389.39, 313.07, 389.39, 313.07, 389.39);
    ctx.translate(305.85813221918517, 371.66068633274136);
    ctx.rotate(0);
    ctx.arc(0, 0, 19.14, 1.1844618426002702, 1.7227985442375564, 0);
    ctx.rotate(0);
    ctx.translate(-305.85813221918517, -371.66068633274136);
    ctx.bezierCurveTo(
      296.14,
      389.46,
      288.38,
      383.84999999999997,
      286.75,
      375.27
    );
    ctx.bezierCurveTo(285.29, 367.64, 291.26, 363.27, 291.94, 362.76);
    ctx.bezierCurveTo(299.7, 357.37, 309.2, 357.08, 320.18, 361.89);
    ctx.bezierCurveTo(321.62, 362.52, 331.18, 369.13, 329.25, 377.89);
    ctx.bezierCurveTo(327.89, 383.94, 324.61, 385.4, 322.44, 386.37);
    ctx.bezierCurveTo(322.14, 386.5, 321.86, 386.63, 321.61, 386.76);
    ctx.translate(322.098024238936, 387.63283007636704);
    ctx.rotate(0);
    ctx.arc(0, 0, 1, -2.080621017245886, -3.078721165420089, 1);
    ctx.rotate(0);
    ctx.translate(-322.098024238936, -387.63283007636704);
    ctx.lineTo(320.56, 398.57);
    ctx.translate(319.70067777952426, 398.5358631958635);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.86, 0.03970438939763163, 1.3249287203518143, 0);
    ctx.rotate(0);
    ctx.translate(-319.70067777952426, -398.5358631958635);
    ctx.translate(319.5056171064622, 398.6566456172322);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.82, 1.0550895022945388, 1.3689618107543173, 0);
    ctx.rotate(0);
    ctx.translate(-319.5056171064622, -398.6566456172322);
    ctx.closePath();
    ctx.moveTo(313.93, 388.87);
    ctx.lineTo(319.56, 398.15);
    ctx.lineTo(320.08, 387.54999999999995);
    ctx.translate(322.01856734790346, 387.62454285775675);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.94, -3.1031590388165284, -2.0465678333160238, 0);
    ctx.rotate(0);
    ctx.translate(-322.01856734790346, -387.62454285775675);
    ctx.bezierCurveTo(
      321.4,
      385.76,
      321.69,
      385.63,
      322.01,
      385.48999999999995
    );
    ctx.bezierCurveTo(
      324.12,
      384.53999999999996,
      327.01,
      383.25999999999993,
      328.25,
      377.69999999999993
    );
    ctx.bezierCurveTo(
      330.08,
      369.5399999999999,
      321.1,
      363.37999999999994,
      319.76,
      362.7899999999999
    );
    ctx.bezierCurveTo(
      309.12,
      358.1299999999999,
      299.95,
      358.38999999999993,
      292.5,
      363.5699999999999
    );
    ctx.bezierCurveTo(
      291.86,
      364.0099999999999,
      286.37,
      368.0599999999999,
      287.71,
      375.07999999999987
    );
    ctx.bezierCurveTo(
      289.26,
      383.1999999999999,
      296.62,
      388.51999999999987,
      303.09999999999997,
      389.57999999999987
    );
    ctx.translate(305.8488264078394, 371.71018317442594);
    ctx.rotate(0);
    ctx.arc(0, 0, 18.08, 1.7234250906786892, 1.1833444536408475, 1);
    ctx.rotate(0);
    ctx.translate(-305.8488264078394, -371.71018317442594);
    ctx.translate(313.06553509389477, 389.372693172932);
    ctx.rotate(0);
    ctx.arc(0, 0, 1, -1.966584005280926, -0.5267113856399008, 0);
    ctx.rotate(0);
    ctx.translate(-313.06553509389477, -389.372693172932);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.translate(-102.17, 111.98);
    ctx.rotate(-0.31956978604016173);
    ctx.beginPath();
    ctx.moveTo(320.91, 376.64);
    ctx.bezierCurveTo(
      320.91,
      377.4849956672411,
      320.24738142974957,
      378.16999999999996,
      319.43,
      378.16999999999996
    );
    ctx.bezierCurveTo(
      318.61261857025045,
      378.16999999999996,
      317.95,
      377.4849956672411,
      317.95,
      376.64
    );
    ctx.bezierCurveTo(
      317.95,
      375.7950043327589,
      318.61261857025045,
      375.11,
      319.43,
      375.11
    );
    ctx.bezierCurveTo(
      320.24738142974957,
      375.11,
      320.91,
      375.7950043327589,
      320.91,
      376.64
    );
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.translate(-102.59, 108.38);
    ctx.rotate(-0.31956978604016173);
    ctx.beginPath();
    ctx.moveTo(309.54, 376.12);
    ctx.bezierCurveTo(
      309.54,
      376.9649956672411,
      308.87738142974956,
      377.65,
      308.06,
      377.65
    );
    ctx.bezierCurveTo(
      307.24261857025044,
      377.65,
      306.58,
      376.9649956672411,
      306.58,
      376.12
    );
    ctx.bezierCurveTo(
      306.58,
      375.2750043327589,
      307.24261857025044,
      374.59000000000003,
      308.06,
      374.59000000000003
    );
    ctx.bezierCurveTo(
      308.87738142974956,
      374.59000000000003,
      309.54,
      375.2750043327589,
      309.54,
      376.12
    );
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.translate(-102.78, 105.03);
    ctx.rotate(-0.31956978604016173);
    ctx.beginPath();
    ctx.moveTo(299.06, 375.05);
    ctx.bezierCurveTo(
      299.06,
      375.8949956672411,
      298.39738142974954,
      376.58,
      297.58,
      376.58
    );
    ctx.bezierCurveTo(
      296.7626185702504,
      376.58,
      296.09999999999997,
      375.8949956672411,
      296.09999999999997,
      375.05
    );
    ctx.bezierCurveTo(
      296.09999999999997,
      374.2050043327589,
      296.7626185702504,
      373.52000000000004,
      297.58,
      373.52000000000004
    );
    ctx.bezierCurveTo(
      298.39738142974954,
      373.52000000000004,
      299.06,
      374.2050043327589,
      299.06,
      375.05
    );
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.restore();
    ctx.save();

    ctx.save();
    fillColor = COLORS[Math.floor(Math.random() * COLORS.length)];
    ctx.fillStyle = fillColor;

    ctx.translate(0, -7.48);
    ctx.beginPath();
    ctx.moveTo(227.67, 48.47);
    ctx.translate(227.6805707901033, 47.60006422168266);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.87, 1.5829469592270138, 2.6114304228156087, 0);
    ctx.rotate(0);
    ctx.translate(-227.6805707901033, -47.60006422168266);
    ctx.lineTo(221.06999999999996, 38.39);
    ctx.lineTo(221.06999999999996, 38.39);
    ctx.translate(213.85813221918517, 20.660686332741324);
    ctx.rotate(0);
    ctx.arc(0, 0, 19.14, 1.1844618426002707, 1.7227985442375555, 0);
    ctx.rotate(0);
    ctx.translate(-213.85813221918517, -20.660686332741324);
    ctx.bezierCurveTo(
      204.14,
      38.46,
      196.37999999999997,
      32.849999999999994,
      194.74999999999997,
      24.269999999999996
    );
    ctx.bezierCurveTo(
      193.28999999999996,
      16.629999999999995,
      199.25999999999996,
      12.269999999999996,
      199.93999999999997,
      11.759999999999996
    );
    ctx.bezierCurveTo(
      207.69999999999996,
      6.3699999999999966,
      217.19999999999996,
      6.0799999999999965,
      228.17999999999998,
      10.889999999999997
    );
    ctx.bezierCurveTo(
      229.61999999999998,
      11.519999999999998,
      239.23,
      18.119999999999997,
      237.24999999999997,
      26.889999999999997
    );
    ctx.bezierCurveTo(
      235.88999999999996,
      32.89,
      232.60999999999999,
      34.4,
      230.43999999999997,
      35.37
    );
    ctx.bezierCurveTo(
      230.13999999999996,
      35.5,
      229.85999999999996,
      35.629999999999995,
      229.60999999999996,
      35.76
    );
    ctx.translate(230.09802423893592, 36.63283007636708);
    ctx.rotate(0);
    ctx.arc(0, 0, 1, -2.080621017245886, -3.078721165420089, 1);
    ctx.rotate(0);
    ctx.translate(-230.09802423893592, -36.63283007636708);
    ctx.lineTo(228.55999999999997, 47.57);
    ctx.translate(227.70067777952423, 47.53586319586346);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.86, 0.039704389397656796, 1.3249287203518494, 0);
    ctx.rotate(0);
    ctx.translate(-227.70067777952423, -47.53586319586346);
    ctx.translate(227.4747092072012, 47.663302097282994);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.83, 1.018731136621566, 1.3332792775686364, 0);
    ctx.rotate(0);
    ctx.translate(-227.4747092072012, -47.663302097282994);
    ctx.closePath();
    ctx.moveTo(221.92999999999998, 37.87);
    ctx.lineTo(227.55999999999997, 47.15);
    ctx.lineTo(228.07999999999998, 36.55);
    ctx.translate(230.01942142297102, 36.59737661998245);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.94, -3.117169287433963, -2.076288188842546, 0);
    ctx.rotate(0);
    ctx.translate(-230.01942142297102, -36.59737661998245);
    ctx.bezierCurveTo(
      229.35,
      34.76,
      229.64,
      34.629999999999995,
      229.95999999999998,
      34.49
    );
    ctx.bezierCurveTo(
      232.07,
      33.49,
      234.95999999999998,
      32.260000000000005,
      236.2,
      26.700000000000003
    );
    ctx.bezierCurveTo(
      238.03,
      18.540000000000003,
      229.04999999999998,
      12.380000000000003,
      227.70999999999998,
      11.790000000000003
    );
    ctx.bezierCurveTo(
      217.07,
      7.130000000000003,
      207.89999999999998,
      7.390000000000002,
      200.45,
      12.570000000000002
    );
    ctx.bezierCurveTo(
      199.81,
      13.010000000000002,
      194.32,
      17.050000000000004,
      195.66,
      24.080000000000002
    );
    ctx.bezierCurveTo(197.21, 32.2, 204.57, 37.52, 211.05, 38.58);
    ctx.translate(213.79882640783944, 20.71018317442609);
    ctx.rotate(0);
    ctx.arc(0, 0, 18.08, 1.7234250906786897, 1.1833444536408464, 1);
    ctx.rotate(0);
    ctx.translate(-213.79882640783944, -20.71018317442609);
    ctx.translate(221.01553509389484, 38.3726931729321);
    ctx.rotate(0);
    ctx.arc(0, 0, 1, -1.9665840052809331, -0.5267113856399139, 0);
    ctx.rotate(0);
    ctx.translate(-221.01553509389484, -38.3726931729321);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.translate(3.46, 65.29);
    ctx.rotate(-0.31956978604016173);
    ctx.beginPath();
    ctx.moveTo(228.91, 25.64);
    ctx.bezierCurveTo(
      228.91,
      26.484995667241115,
      228.2473814297496,
      27.17,
      227.43,
      27.17
    );
    ctx.bezierCurveTo(
      226.61261857025042,
      27.17,
      225.95000000000002,
      26.484995667241115,
      225.95000000000002,
      25.64
    );
    ctx.bezierCurveTo(
      225.95000000000002,
      24.795004332758886,
      226.61261857025042,
      24.11,
      227.43,
      24.11
    );
    ctx.bezierCurveTo(
      228.2473814297496,
      24.11,
      228.91,
      24.795004332758886,
      228.91,
      25.64
    );
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.translate(3.05, 61.69);
    ctx.rotate(-0.31956978604016173);
    ctx.beginPath();
    ctx.moveTo(217.54, 25.12);
    ctx.bezierCurveTo(
      217.54,
      25.964995667241116,
      216.8773814297496,
      26.650000000000002,
      216.06,
      26.650000000000002
    );
    ctx.bezierCurveTo(
      215.24261857025041,
      26.650000000000002,
      214.58,
      25.964995667241116,
      214.58,
      25.12
    );
    ctx.bezierCurveTo(
      214.58,
      24.275004332758886,
      215.24261857025041,
      23.59,
      216.06,
      23.59
    );
    ctx.bezierCurveTo(
      216.8773814297496,
      23.59,
      217.54,
      24.275004332758886,
      217.54,
      25.12
    );
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.translate(2.86, 58.34);
    ctx.rotate(-0.31956978604016173);
    ctx.beginPath();
    ctx.moveTo(207.06, 24.05);
    ctx.bezierCurveTo(
      207.06,
      24.894995667241115,
      206.3973814297496,
      25.580000000000002,
      205.58,
      25.580000000000002
    );
    ctx.bezierCurveTo(
      204.76261857025042,
      25.580000000000002,
      204.10000000000002,
      24.894995667241115,
      204.10000000000002,
      24.05
    );
    ctx.bezierCurveTo(
      204.10000000000002,
      23.205004332758886,
      204.76261857025042,
      22.52,
      205.58,
      22.52
    );
    ctx.bezierCurveTo(
      206.3973814297496,
      22.52,
      207.06,
      23.205004332758886,
      207.06,
      24.05
    );
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.restore();
    ctx.save();

    ctx.save();
    fillColor = COLORS[Math.floor(Math.random() * COLORS.length)];
    ctx.fillStyle = fillColor;

    ctx.translate(0, -7.48);
    ctx.beginPath();
    ctx.moveTo(399.5, 77.05);
    ctx.translate(413.9006431840455, 109.51986103890505);
    ctx.rotate(0);
    ctx.arc(0, 0, 35.52, -1.988238406683731, -1.5679991154907766, 0);
    ctx.rotate(0);
    ctx.translate(-413.9006431840455, -109.51986103890505);
    ctx.lineTo(414, 73);
    ctx.translate(413.8742513838174, 109.28978213334338);
    ctx.rotate(0);
    ctx.arc(0, 0, 36.29, -1.5673312160804644, -1.9891861052585937, 1);
    ctx.rotate(0);
    ctx.translate(-413.8742513838174, -109.28978213334338);
    ctx.bezierCurveTo(
      397.71999999999997,
      76.71,
      388.32,
      82.83999999999999,
      390.26,
      91.00999999999999
    );
    ctx.bezierCurveTo(
      391.59,
      96.61999999999999,
      394.8,
      98.00999999999999,
      396.92,
      98.86999999999999
    );
    ctx.bezierCurveTo(
      397.22,
      98.99999999999999,
      397.49,
      99.10999999999999,
      397.74,
      99.22999999999999
    );
    ctx.translate(397.38050722616777, 99.98918702936918);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.84, -1.1285535060267897, -0.03475345900042259, 0);
    ctx.rotate(0);
    ctx.translate(-397.38050722616777, -99.98918702936918);
    ctx.lineTo(398.75, 110.16999999999999);
    ctx.translate(399.559532588179, 110.14248657280133);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.81, 3.107618924400676, 1.8069767994566126, 1);
    ctx.rotate(0);
    ctx.translate(-399.559532588179, -110.14248657280133);
    ctx.lineTo(399.59000000000003, 110.92999999999999);
    ctx.translate(399.5952170055452, 110.08001601023716);
    ctx.rotate(0);
    ctx.arc(0, 0, 0.85, 1.5769340189131351, 0.5718131278669247, 1);
    ctx.rotate(0);
    ctx.translate(-399.5952170055452, -110.08001601023716);
    ctx.lineTo(406.0300000000001, 101.60999999999999);
    ctx.bezierCurveTo(
      406.0300000000001,
      101.60999999999999,
      406.0300000000001,
      101.60999999999999,
      406.0300000000001,
      101.60999999999999
    );
    ctx.translate(413.0916265855353, 83.2191481989968);
    ctx.rotate(0);
    ctx.arc(0, 0, 19.7, 1.9374121453062898, 1.5267021707577895, 1);
    ctx.rotate(0);
    ctx.translate(-413.0916265855353, -83.2191481989968);
    ctx.lineTo(413.9600000000001, 101.89999999999999);
    ctx.translate(413.1415291837785, 82.9176369879039);
    ctx.rotate(0);
    ctx.arc(0, 0, 19, 1.5277055814148703, 1.9352043718930485, 0);
    ctx.rotate(0);
    ctx.translate(-413.1415291837785, -82.9176369879039);
    ctx.translate(406.0149489742784, 101.60484692283495);
    ctx.rotate(0);
    ctx.arc(0, 0, 1, -1.2078276781892687, -2.577266084193823, 1);
    ctx.rotate(0);
    ctx.translate(-406.0149489742784, -101.60484692283495);
    ctx.lineTo(399.67000000000013, 109.66);
    ctx.lineTo(399.16000000000014, 99.87);
    ctx.translate(397.3021974471228, 99.96038625184444);
    ctx.rotate(0);
    ctx.arc(0, 0, 1.86, -0.04861390509594367, -1.0914670223034717, 1);
    ctx.rotate(0);
    ctx.translate(-397.3021974471228, -99.96038625184444);
    ctx.bezierCurveTo(
      397.90000000000015,
      98.18,
      397.6100000000001,
      98.06,
      397.3000000000001,
      97.93
    );
    ctx.bezierCurveTo(
      395.2400000000001,
      97.06,
      392.4300000000001,
      95.87,
      391.21000000000015,
      90.75
    );
    ctx.bezierCurveTo(389.43, 83.28, 398.19, 77.6, 399.5, 77.05);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.translate(-9.76, 95.46);
    ctx.rotate(-0.2528982086139784);
    ctx.beginPath();
    ctx.moveTo(401.28999999999996, 89.84);
    ctx.bezierCurveTo(
      401.28999999999996,
      90.61319864976312,
      400.63633573475295,
      91.24000000000001,
      399.83,
      91.24000000000001
    );
    ctx.bezierCurveTo(
      399.023664265247,
      91.24000000000001,
      398.37,
      90.61319864976312,
      398.37,
      89.84
    );
    ctx.bezierCurveTo(
      398.37,
      89.06680135023689,
      399.023664265247,
      88.44,
      399.83,
      88.44
    );
    ctx.bezierCurveTo(
      400.63633573475295,
      88.44,
      401.28999999999996,
      89.06680135023689,
      401.28999999999996,
      89.84
    );
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.translate(-9.29, 98.22);
    ctx.rotate(-0.2528982086139784);
    ctx.beginPath();
    ctx.moveTo(412.4, 89.36);
    ctx.bezierCurveTo(
      412.4,
      90.13319864976312,
      411.74633573475296,
      90.76,
      410.94,
      90.76
    );
    ctx.bezierCurveTo(
      410.13366426524703,
      90.76,
      409.48,
      90.13319864976312,
      409.48,
      89.36
    );
    ctx.bezierCurveTo(
      409.48,
      88.58680135023688,
      410.13366426524703,
      87.96,
      410.94,
      87.96
    );
    ctx.bezierCurveTo(
      411.74633573475296,
      87.96,
      412.4,
      88.58680135023688,
      412.4,
      89.36
    );
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.restore();
    ctx.save();
    ctx.fillStyle = fillColor;

    ctx.translate(0, -7.48);
    ctx.beginPath();
    ctx.moveTo(12.69, 77);
    ctx.translate(-0.5059403176057984, 96.73460815760438);
    ctx.rotate(0);
    ctx.arc(0, 0, 23.74, -0.9814080864148224, -1.5494829896324083, 1);
    ctx.rotate(0);
    ctx.translate(0.5059403176057984, -96.73460815760438);
    ctx.lineTo(0, 74);
    ctx.translate(-0.4414504021909291, 96.83573343561369);
    ctx.rotate(0);
    ctx.arc(0, 0, 22.84, -1.5514671721439521, -0.9868873889133618, 0);
    ctx.rotate(0);
    ctx.translate(0.4414504021909291, -96.83573343561369);
    ctx.bezierCurveTo(12.77, 78.18, 18.15, 81.92, 16.82, 88.39);
    ctx.bezierCurveTo(15.31, 95.89, 8.11, 100.81, 1.8200000000000003, 101.79);
    ctx.translate(-1.1253100070547664, 84.25564660552484);
    ctx.rotate(0);
    ctx.arc(0, 0, 17.78, 1.404376223072881, 1.5074632196831201, 0);
    ctx.rotate(0);
    ctx.translate(1.1253100070547664, -84.25564660552484);
    ctx.lineTo(0, 103);
    ctx.translate(-0.7760614541756432, 85.07679357315375);
    ctx.rotate(0);
    ctx.arc(0, 0, 17.94, 1.5275241026561173, 1.4188149564578394, 1);
    ctx.rotate(0);
    ctx.translate(0.7760614541756432, -85.07679357315375);
    ctx.bezierCurveTo(8.6, 101.81, 16.18, 96.58, 17.78, 88.63);
    ctx.bezierCurveTo(19.21, 81.47, 13.36, 77.39, 12.69, 77);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.save();
    fillColor = COLORS[Math.floor(Math.random() * COLORS.length)];
    ctx.fillStyle = COLORS[Math.floor(Math.random() * COLORS.length)];

    ctx.translate(-21.89, -2.87);
    ctx.rotate(-0.2528982086139784);
    ctx.beginPath();
    ctx.moveTo(8.629999999999999, 88.36);
    ctx.bezierCurveTo(
      8.629999999999999,
      89.13319864976312,
      7.976335734752959,
      89.76,
      7.17,
      89.76
    );
    ctx.bezierCurveTo(
      6.363664265247041,
      89.76,
      5.71,
      89.13319864976312,
      5.71,
      88.36
    );
    ctx.bezierCurveTo(
      5.71,
      87.58680135023688,
      6.363664265247041,
      86.96,
      7.17,
      86.96
    );
    ctx.bezierCurveTo(
      7.976335734752959,
      86.96,
      8.629999999999999,
      87.58680135023688,
      8.629999999999999,
      88.36
    );
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    ctx.restore();

    let wizardCanvasBackground = document.createElement("canvas");
    let wizardCtx = wizardCanvasBackground.getContext("2d");

    wizardCanvasBackground.height = $(window).height();
    wizardCanvasBackground.width = $(window).width();

    let pattern = wizardCtx.createPattern(this.element, "repeat");

    wizardCtx.fillStyle = pattern;
    wizardCtx.fillRect =
      (0, 0, wizardCanvasBackground.width, wizardCanvasBackground.height);

    document.body.appendChild(wizardCanvasBackground);
  },
});
