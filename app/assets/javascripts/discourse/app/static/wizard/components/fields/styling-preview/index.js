import { action } from "@ember/object";
import { observes } from "@ember-decorators/object";
import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import {
  chooseDarker,
  darkLightDiff,
  resizeTextLinesToFitRect,
} from "../../../lib/preview";
import HomepagePreview from "./-homepage-preview";
import PreviewBaseComponent from "./-preview-base";

export default class Index extends PreviewBaseComponent {
  width = 630;
  height = 380;
  logo = null;
  avatar = null;
  previewTopic = true;
  draggingActive = false;
  startX = 0;
  scrollLeft = 0;
  HomepagePreview = HomepagePreview;

  init() {
    super.init(...arguments);
    this.step
      .findField("homepage_style")
      ?.addListener(this.onHomepageStyleChange);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.step
      .findField("homepage_style")
      ?.removeListener(this.onHomepageStyleChange);
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.element.addEventListener("mouseleave", this.handleMouseLeave);
    this.element.addEventListener("mousemove", this.handleMouseMove);
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    this.element.removeEventListener("mouseleave", this.handleMouseLeave);
    this.element.removeEventListener("mousemove", this.handleMouseMove);
  }

  mouseDown(e) {
    const slider = this.element.querySelector(".previews");
    this.setProperties({
      draggingActive: true,
      startX: e.pageX - slider.offsetLeft,
      scrollLeft: slider.scrollLeft,
    });
  }

  @bind
  handleMouseLeave() {
    this.set("draggingActive", false);
  }

  mouseUp() {
    this.set("draggingActive", false);
  }

  @bind
  handleMouseMove(e) {
    if (!this.draggingActive) {
      return;
    }
    e.preventDefault();

    const slider = this.element.querySelector(".previews"),
      x = e.pageX - slider.offsetLeft,
      walk = (x - this.startX) * 1.5;

    slider.scrollLeft = this.scrollLeft - walk;

    if (slider.scrollLeft < 50) {
      this.set("previewTopic", true);
    }
    if (slider.scrollLeft > slider.offsetWidth - 50) {
      this.set("previewTopic", false);
    }
  }

  didUpdateAttrs() {
    super.didUpdateAttrs(...arguments);

    this.triggerRepaint();
  }

  @bind
  onHomepageStyleChange() {
    this.set("previewTopic", false);
  }

  @observes("previewTopic")
  scrollPreviewArea() {
    const el = this.element.querySelector(".previews");
    el.scrollTo({
      top: 0,
      left: this.previewTopic ? 0 : el.scrollWidth - el.offsetWidth,
      behavior: "smooth",
    });
  }

  images() {
    return {
      logo: this.wizard.logoUrl,
      avatar: "/images/wizard/trout.png",
    };
  }

  paint({ ctx, colors, font, headingFont, width, height }) {
    this.drawFullHeader(colors, headingFont, this.logo);

    const margin = 20;
    const avatarSize = height * 0.1 + 5;
    const lineHeight = height / 14;
    const leftHandTextGutter = margin + avatarSize + margin;
    const timelineX = width * 0.86;

    // Draw a fake topic
    this.scaleImage(
      this.avatar,
      margin,
      this.headerHeight + height * 0.22,
      avatarSize,
      avatarSize
    );

    const titleFontSize = this.headerHeight / 30;

    // Topic title
    ctx.beginPath();
    ctx.fillStyle = colors.primary;
    ctx.font = `700 ${titleFontSize}em '${headingFont}'`;
    ctx.fillText(i18n("wizard.previews.topic_title"), margin, height * 0.3);

    // Topic OP text
    const bodyFontSize = 1;
    ctx.font = `${bodyFontSize}em '${font}'`;

    let verticalLinePos = 0;
    const topicOp = i18n("wizard.homepage_preview.topic_ops.what_books");
    const topicOpLines = topicOp.split("\n");

    resizeTextLinesToFitRect(
      topicOpLines,
      timelineX - leftHandTextGutter,
      ctx,
      bodyFontSize,
      font,
      (textLine, idx) => {
        verticalLinePos = height * 0.4 + idx * lineHeight;
        ctx.fillText(textLine, leftHandTextGutter, verticalLinePos);
      }
    );

    ctx.font = `${bodyFontSize}em '${font}'`;

    // Share button
    const shareButtonWidth =
      Math.round(ctx.measureText(i18n("wizard.previews.share_button")).width) +
      margin;

    ctx.beginPath();
    ctx.rect(margin, verticalLinePos, shareButtonWidth, height * 0.1);
    // accounts for hard-set color variables in solarized themes
    ctx.fillStyle =
      colors.primary_low ||
      darkLightDiff(colors.primary, colors.secondary, 90, 65);
    ctx.fill();
    ctx.fillStyle = chooseDarker(colors.primary, colors.secondary);
    ctx.fillText(
      i18n("wizard.previews.share_button"),
      margin + 10,
      verticalLinePos + lineHeight * 0.9
    );

    // Reply button
    const replyButtonWidth =
      Math.round(ctx.measureText(i18n("wizard.previews.reply_button")).width) +
      margin;

    ctx.beginPath();
    ctx.rect(
      shareButtonWidth + margin + 10,
      verticalLinePos,
      replyButtonWidth,
      height * 0.1
    );
    ctx.fillStyle = colors.tertiary;
    ctx.fill();
    ctx.fillStyle = colors.secondary;
    ctx.fillText(
      i18n("wizard.previews.reply_button"),
      shareButtonWidth + margin * 2,
      verticalLinePos + lineHeight * 0.9
    );

    // Draw timeline
    ctx.beginPath();
    ctx.strokeStyle = colors.tertiary;
    ctx.lineWidth = 0.5;
    ctx.moveTo(timelineX, height * 0.3);
    ctx.lineTo(timelineX, height * 0.7);
    ctx.stroke();

    // Timeline handle
    ctx.beginPath();
    ctx.strokeStyle = colors.tertiary;
    ctx.lineWidth = 3;
    ctx.moveTo(timelineX, height * 0.3 + 10);
    ctx.lineTo(timelineX, height * 0.4);
    ctx.stroke();

    // Timeline post count
    const postCountY = height * 0.3 + margin + 10;
    ctx.beginPath();
    ctx.font = `700 ${bodyFontSize}em '${font}'`;
    ctx.fillStyle = colors.primary;
    ctx.fillText("1 / 20", timelineX + margin / 2, postCountY);

    // Timeline post date
    ctx.beginPath();
    ctx.font = `${bodyFontSize * 0.9}em '${font}'`;
    ctx.fillStyle = darkLightDiff(colors.primary, colors.secondary, 70, 65);
    ctx.fillText(
      "Nov 22",
      timelineX + margin / 2,
      postCountY + lineHeight * 0.75
    );
  }

  @action
  setPreviewHomepage(event) {
    event?.preventDefault();
    this.set("previewTopic", false);
  }

  @action
  setPreviewTopic(event) {
    event?.preventDefault();
    this.set("previewTopic", true);
  }
}
