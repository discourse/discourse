const MAX_PARTICLES = 150;

const SIZE = 144;

let width, height;

const COLORS = ['#BF1E2E', '#F1592A', '#F7941D', '#9EB83B', '#3AB54A', '#12A89D', '#25AAE2', '#0E76BD',
                '#652D90', '#92278F', '#ED207B', '#8C6238'];

class Particle {
  constructor() {
    this.reset();
    this.y = (Math.random() * (height + SIZE)) - SIZE;
  }

  reset() {
    this.y = -SIZE;
    this.origX = Math.random() * (width + SIZE);
    this.speed = 1 + Math.random();
    this.ang = Math.random() * 2 * Math.PI;
    this.scale = (Math.random() * 0.4) + 0.2;
    this.radius = (Math.random() * 25) + 25;
    this.color = COLORS[Math.floor(Math.random() * COLORS.length)];
    this.flipped = (Math.random() > 0.5) ? 1 : -1;
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

    this.x = this.origX + (this.radius * Math.sin(this.ang));
  }
}

export default Ember.Component.extend({
  classNames: ['wizard-canvas'],
  tagName: 'canvas',
  ctx: null,
  ready: false,
  particles: null,

  didInsertElement() {
    this._super();

    const canvas = this.$()[0];
    this.ctx = canvas.getContext('2d');
    this.resized();

    this.particles = [];
    for (let i=0; i<MAX_PARTICLES; i++) {
      this.particles.push(new Particle());
    }

    this.ready = true;
    this.paint();

    $(window).on('resize.wizard', () => this.resized());
  },

  willDestroyElement() {
    this._super();
    $(window).off('resize.wizard');
  },

  resized() {
    width = $(window).width();
    height = $(window).height();

    const canvas = this.$()[0];
    canvas.width = width;
    canvas.height = height;
  },

  paint() {
    if (this.isDestroying || this.isDestroyed || !this.ready) { return; }

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
    c.moveTo(97.90, 194.90);
    c.lineTo(103.50, 162.90);
    c.bezierCurveTo(88.70, 152, 84.20, 139.70, 90.20, 126.30);
    c.bezierCurveTo(99.50, 105.60, 124.60, 89.60, 159.70, 100.40);
    c.lineTo(159.70, 100.40);
    c.bezierCurveTo(175.90, 105.40, 186.40, 111.20, 192.60, 118.50);
    c.bezierCurveTo(200, 127.20, 201.60, 138.40, 197.50, 152.70);
    c.bezierCurveTo(194, 165, 187.40, 173.60, 177.90, 178.30);
    c.bezierCurveTo(165.60, 184.40, 148.40, 183.70, 129.40, 176.30);
    c.bezierCurveTo(127.70, 175.60, 126, 174.90, 124.40, 174.20);
    c.lineTo(97.90, 194.90);
    c.closePath();
    c.moveTo(138, 99.30);
    c.bezierCurveTo(115.40, 99.30, 99.30, 111.90, 92.40, 127.30);
    c.bezierCurveTo(86.80, 139.70, 91.20, 151.20, 105.50, 161.50);
    c.lineTo(106.10, 161.90);
    c.lineTo(101.20, 189.40);
    c.lineTo(124, 171.70);
    c.lineTo(124.60, 172);
    c.bezierCurveTo(126.40, 172.80, 128.30, 173.60, 130.20, 174.30);
    c.bezierCurveTo(148.60, 181.40, 165.10, 182.20, 176.80, 176.40);
    c.bezierCurveTo(185.70, 172, 191.90, 163.90, 195.20, 152.20);
    c.bezierCurveTo(202.40, 127.20, 191.90, 112.80, 159, 102.70);
    c.lineTo(159, 102.70);
    c.bezierCurveTo(151.60, 100.30, 144.50, 99.30, 138, 99.30);
    c.closePath();
    c.fill();
    c.stroke();
    c.beginPath();
    c.moveTo(115.70, 136.20);
    c.bezierCurveTo(115.70, 137.90, 115, 139.30, 113.30, 139.30);
    c.bezierCurveTo(111.60, 139.30, 110.20, 137.90, 110.20, 136.20);
    c.bezierCurveTo(110.20, 134.50, 111.60, 133.10, 113.30, 133.10);
    c.bezierCurveTo(115, 133, 115.70, 134.40, 115.70, 136.20);
    c.closePath();
    c.fill();
    c.stroke();
    c.beginPath();
    c.moveTo(145.80, 141.60);
    c.bezierCurveTo(145.80, 143.30, 144.40, 144.10, 142.70, 144.10);
    c.bezierCurveTo(141, 144.10, 139.60, 143.40, 139.60, 141.60);
    c.bezierCurveTo(139.60, 141.60, 141, 138.50, 142.70, 138.50);
    c.bezierCurveTo(144.40, 138.50, 145.80, 139.90, 145.80, 141.60);
    c.closePath();
    c.fill();
    c.stroke();
    c.beginPath();
    c.moveTo(171.60, 146.80);
    c.bezierCurveTo(171.60, 148.50, 171, 149.90, 169.20, 149.90);
    c.bezierCurveTo(167.50, 149.90, 166.10, 148.50, 166.10, 146.80);
    c.bezierCurveTo(166.10, 145.10, 167.50, 143.70, 169.20, 143.70);
    c.bezierCurveTo(171, 143.60, 171.60, 145, 171.60, 146.80);
    c.closePath();
    c.fill();
    c.stroke();
    c.restore();
  }
});
