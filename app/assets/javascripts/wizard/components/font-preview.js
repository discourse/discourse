import I18n from "I18n";
import { observes } from "discourse-common/utils/decorators";
import {
  createPreviewComponent,
  darkLightDiff,
  chooseDarker,
} from "wizard/lib/preview";

const LOREM = `
Lorem ipsum dolor sit amet, consectetur adipiscing.
Nullam eget sem non elit tincidunt rhoncus. Fusce
velit nisl, porttitor sed nisl ac, consectetur interdum
metus. Fusce in consequat augue, vel facilisis felis.`;

export default createPreviewComponent(659, 320, {
  logo: null,
  avatar: null,

  @observes(
    "step.fieldsById.body_font.value",
    "step.fieldsById.heading_font.value"
  )
  fontChanged() {
    this.triggerRepaint();
  },

  images() {
    return {
      logo: this.wizard.getLogoUrl(),
      avatar: "/images/wizard/trout.png",
    };
  },

  paint({ ctx, colors, font, headingFont, width, height }) {
    const headerHeight = height * 0.3;

    this.drawFullHeader(colors, headingFont, this.logo);

    const margin = width * 0.04;
    const avatarSize = height * 0.2;
    const lineHeight = height / 11;

    // Draw a fake topic
    this.scaleImage(
      this.avatar,
      margin,
      headerHeight + height * 0.11,
      avatarSize,
      avatarSize
    );

    const titleFontSize = headerHeight / 55;

    ctx.beginPath();
    ctx.fillStyle = colors.primary;
    ctx.font = `bold ${titleFontSize}em '${headingFont}'`;
    ctx.fillText(I18n.t("wizard.previews.topic_title"), margin, height * 0.3);

    const bodyFontSize = height / 330.0;
    ctx.font = `${bodyFontSize}em '${font}'`;

    let line = 0;
    const lines = LOREM.split("\n");
    for (let i = 0; i < 5; i++) {
      line = height * 0.35 + i * lineHeight;
      ctx.fillText(lines[i], margin + avatarSize + margin, line);
    }

    // Share Button
    ctx.beginPath();
    ctx.rect(margin, line + lineHeight, width * 0.1, height * 0.12);
    ctx.fillStyle = darkLightDiff(colors.primary, colors.secondary, 90, 65);
    ctx.fill();
    ctx.fillStyle = chooseDarker(colors.primary, colors.secondary);
    ctx.font = `${bodyFontSize}em '${font}'`;
    ctx.fillText(
      I18n.t("wizard.previews.share_button"),
      margin + width / 55,
      line + lineHeight * 1.85
    );

    // Reply Button
    ctx.beginPath();
    ctx.rect(
      margin + width * 0.12,
      line + lineHeight,
      width * 0.1,
      height * 0.12
    );
    ctx.fillStyle = colors.tertiary;
    ctx.fill();
    ctx.fillStyle = colors.secondary;
    ctx.font = `${bodyFontSize}em '${font}'`;
    ctx.fillText(
      I18n.t("wizard.previews.reply_button"),
      margin + width * 0.12 + width / 55,
      line + lineHeight * 1.85
    );

    // Draw Timeline
    const timelineX = width * 0.86;
    ctx.beginPath();
    ctx.strokeStyle = colors.tertiary;
    ctx.lineWidth = 0.5;
    ctx.moveTo(timelineX, height * 0.3);
    ctx.lineTo(timelineX, height * 0.7);
    ctx.stroke();

    // Timeline
    ctx.beginPath();
    ctx.strokeStyle = colors.tertiary;
    ctx.lineWidth = 2;
    ctx.moveTo(timelineX, height * 0.3);
    ctx.lineTo(timelineX, height * 0.4);
    ctx.stroke();

    ctx.font = `Bold ${bodyFontSize}em ${font}`;
    ctx.fillStyle = colors.primary;
    ctx.fillText("1 / 20", timelineX + margin, height * 0.3 + margin * 1.5);
  },
});
