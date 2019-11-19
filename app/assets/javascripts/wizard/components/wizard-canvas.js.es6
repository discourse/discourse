import Component from "@ember/component";
const MAX_PARTICLES = 150;

const SIZE = 144;

let width, height;

const COLORS = [
  "#BF1E2E",
  "#F1592A",
  "#F7941D",
  "#9EB83B",
  "#3AB54A",
  "#12A89D",
  "#25AAE2",
  "#0E76BD",
  "#652D90",
  "#92278F",
  "#ED207B",
  "#8C6238"
];

class Particle {
  constructor() {
    this.reset();
    this.y = Math.random() * (height + SIZE) - SIZE;
  }

  reset() {
    this.y = -SIZE;
    this.origX = Math.random() * (width + SIZE);
    this.speed = 1 + Math.random();
    this.ang = Math.random() * 2 * Math.PI;
    this.scale = Math.random() * 0.4 + 0.2;
    this.radius = Math.random() * 25 + 25;
    this.color = COLORS[Math.floor(Math.random() * COLORS.length)];
    this.flipped = Math.random() > 0.5 ? 1 : -1;
  }

  move() {
    this.y += this.speed;

    if (this.y > height + SIZE) {
      this.reset();
    }

    this.ang += this.speed / 30.0;
    if (this.ang > 2 * Math.PI) {
      this.ang = 0;
    }

    this.x = this.origX + this.radius * Math.sin(this.ang);
  }
}

export default Component.extend({
  classNames: ["wizard-canvas"],
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
    canvas.width = width;
    canvas.height = height;
  },

  paint() {
    if (this.isDestroying || this.isDestroyed || !this.ready) {
      return;
    }

    const { ctx } = this;
    ctx.clearRect(0, 0, width, height);

    this.particles.forEach(particle => {
      particle.move();
      this.drawParticle(particle);
    });

    window.requestAnimationFrame(() => this.paint());
  },

  drawParticle(p) {
    const c = this.ctx;

    c.save();
    c.translate(p.x - SIZE, p.y - SIZE);
    c.scale(p.scale * p.flipped, p.scale);
    c.fillStyle = p.color;
    c.strokeStyle = p.color;
    c.globalAlpha = "1.0";
    c.lineWidth = "1";
    c.lineCap = "butt";
    c.lineJoin = "round";
    c.mitterLimit = "1";
    c.beginPath();
    c.moveTo(97.9, 194.9);
    c.lineTo(103.5, 162.9);
    c.bezierCurveTo(88.7, 152, 84.2, 139.7, 90.2, 126.3);
    c.bezierCurveTo(99.5, 105.6, 124.6, 89.6, 159.7, 100.4);
    c.lineTo(159.7, 100.4);
    c.bezierCurveTo(175.9, 105.4, 186.4, 111.2, 192.6, 118.5);
    c.bezierCurveTo(200, 127.2, 201.6, 138.4, 197.5, 152.7);
    c.bezierCurveTo(194, 165, 187.4, 173.6, 177.9, 178.3);
    c.bezierCurveTo(165.6, 184.4, 148.4, 183.7, 129.4, 176.3);
    c.bezierCurveTo(127.7, 175.6, 126, 174.9, 124.4, 174.2);
    c.lineTo(97.9, 194.9);
    c.closePath();
    c.moveTo(138, 99.3);
    c.bezierCurveTo(115.4, 99.3, 99.3, 111.9, 92.4, 127.3);
    c.bezierCurveTo(86.8, 139.7, 91.2, 151.2, 105.5, 161.5);
    c.lineTo(106.1, 161.9);
    c.lineTo(101.2, 189.4);
    c.lineTo(124, 171.7);
    c.lineTo(124.6, 172);
    c.bezierCurveTo(126.4, 172.8, 128.3, 173.6, 130.2, 174.3);
    c.bezierCurveTo(148.6, 181.4, 165.1, 182.2, 176.8, 176.4);
    c.bezierCurveTo(185.7, 172, 191.9, 163.9, 195.2, 152.2);
    c.bezierCurveTo(202.4, 127.2, 191.9, 112.8, 159, 102.7);
    c.lineTo(159, 102.7);
    c.bezierCurveTo(151.6, 100.3, 144.5, 99.3, 138, 99.3);
    c.closePath();
    c.fill();
    c.stroke();
    c.beginPath();
    c.moveTo(115.7, 136.2);
    c.bezierCurveTo(115.7, 137.9, 115, 139.3, 113.3, 139.3);
    c.bezierCurveTo(111.6, 139.3, 110.2, 137.9, 110.2, 136.2);
    c.bezierCurveTo(110.2, 134.5, 111.6, 133.1, 113.3, 133.1);
    c.bezierCurveTo(115, 133, 115.7, 134.4, 115.7, 136.2);
    c.closePath();
    c.fill();
    c.stroke();
    c.beginPath();
    c.moveTo(145.8, 141.6);
    c.bezierCurveTo(145.8, 143.3, 144.4, 144.1, 142.7, 144.1);
    c.bezierCurveTo(141, 144.1, 139.6, 143.4, 139.6, 141.6);
    c.bezierCurveTo(139.6, 141.6, 141, 138.5, 142.7, 138.5);
    c.bezierCurveTo(144.4, 138.5, 145.8, 139.9, 145.8, 141.6);
    c.closePath();
    c.fill();
    c.stroke();
    c.beginPath();
    c.moveTo(171.6, 146.8);
    c.bezierCurveTo(171.6, 148.5, 171, 149.9, 169.2, 149.9);
    c.bezierCurveTo(167.5, 149.9, 166.1, 148.5, 166.1, 146.8);
    c.bezierCurveTo(166.1, 145.1, 167.5, 143.7, 169.2, 143.7);
    c.bezierCurveTo(171, 143.6, 171.6, 145, 171.6, 146.8);
    c.closePath();
    c.fill();
    c.stroke();
    c.restore();
  }
});
