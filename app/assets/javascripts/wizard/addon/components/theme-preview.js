import {
  LOREM,
  chooseDarker,
  createPreviewComponent,
  darkLightDiff,
} from "wizard/lib/preview";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import I18n from "I18n";

export default createPreviewComponent(305, 165, {
  logo: null,
  avatar: null,

  classNameBindings: ["isSelected"],

  @discourseComputed("selectedId", "colorsId")
  isSelected(selectedId, colorsId) {
    return selectedId === colorsId;
  },

  click() {
    this.onChange(this.colorsId);
  },

  @observes("step.fieldsById.base_scheme_id.value")
  themeChanged() {
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
    const lineHeight = height / 9.5;

    // Draw a fake topic
    this.scaleImage(
      this.avatar,
      margin,
      headerHeight + height * 0.085,
      avatarSize,
      avatarSize
    );

    const titleFontSize = headerHeight / 44;

    ctx.beginPath();
    ctx.fillStyle = colors.primary;
    ctx.font = `bold ${titleFontSize}em '${headingFont}'`;
    ctx.fillText(I18n.t("wizard.previews.topic_title"), margin, height * 0.3);

    const bodyFontSize = height / 220.0;
    ctx.font = `${bodyFontSize}em '${font}'`;

    let line = 0;
    const lines = LOREM.split("\n");
    for (let i = 0; i < 4; i++) {
      line = height * 0.35 + i * lineHeight;
      ctx.fillText(lines[i], margin + avatarSize + margin, line);
    }

    // Share Button
    const shareButtonWidth = I18n.t("wizard.previews.share_button").length * 9;

    ctx.beginPath();
    ctx.rect(margin, line + lineHeight, shareButtonWidth, height * 0.14);
    ctx.fillStyle = darkLightDiff(colors.primary, colors.secondary, 90, 65);
    ctx.fill();
    ctx.fillStyle = chooseDarker(colors.primary, colors.secondary);
    ctx.font = `${bodyFontSize}em '${font}'`;
    ctx.fillText(
      I18n.t("wizard.previews.share_button"),
      margin + 8,
      line + lineHeight * 1.85
    );

    // Reply Button
    const replyButtonWidth = I18n.t("wizard.previews.reply_button").length * 9;
    ctx.beginPath();
    ctx.rect(
      shareButtonWidth + margin + 10,
      line + lineHeight,
      replyButtonWidth,
      height * 0.14
    );
    ctx.fillStyle = colors.tertiary;
    ctx.fill();
    ctx.fillStyle = colors.secondary;
    ctx.font = `${bodyFontSize}em '${font}'`;
    ctx.fillText(
      I18n.t("wizard.previews.reply_button"),
      shareButtonWidth + margin + 18,
      line + lineHeight * 1.85
    );

    // Draw Timeline
    const timelineX = width * 0.8;
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
