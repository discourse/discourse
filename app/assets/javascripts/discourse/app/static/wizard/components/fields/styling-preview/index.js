import { action } from "@ember/object";
import { observes } from "@ember-decorators/object";
import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import { chooseDarker, darkLightDiff } from "../../../lib/preview";
import HomepagePreview from "./-homepage-preview";
import PreviewBaseComponent from "./-preview-base";

export default class Index extends PreviewBaseComponent {
  width = 628;
  height = 322;
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
    const headerHeight = height * 0.3;

    this.drawFullHeader(colors, headingFont, this.logo);

    const margin = 20;
    const avatarSize = height * 0.15;
    const lineHeight = height / 14;

    // Draw a fake topic
    this.scaleImage(
      this.avatar,
      margin,
      headerHeight + height * 0.09,
      avatarSize,
      avatarSize
    );

    const titleFontSize = headerHeight / 55;

    ctx.beginPath();
    ctx.fillStyle = colors.primary;
    ctx.font = `bold ${titleFontSize}em '${headingFont}'`;
    ctx.fillText(i18n("wizard.previews.topic_title"), margin, height * 0.3);

    const bodyFontSize = height / 330.0;
    ctx.font = `${bodyFontSize}em '${font}'`;

    let line = 0;
    const lines = i18n("wizard.homepage_preview.topic_ops.what_books").split(
      "\n"
    );
    for (let i = 0; i < lines.length; i++) {
      line = height * 0.35 + i * lineHeight;
      ctx.fillText(lines[i], margin + avatarSize + margin, line);
    }

    // Share Button
    const shareButtonWidth = i18n("wizard.previews.share_button").length * 11;

    ctx.beginPath();
    ctx.rect(margin, line + lineHeight, shareButtonWidth, height * 0.1);
    // accounts for hard-set color variables in solarized themes
    ctx.fillStyle =
      colors.primary_low ||
      darkLightDiff(colors.primary, colors.secondary, 90, 65);
    ctx.fillStyle = chooseDarker(colors.primary, colors.secondary);
    ctx.font = `${bodyFontSize}em '${font}'`;
    ctx.fillText(
      i18n("wizard.previews.share_button"),
      margin + 10,
      line + lineHeight * 1.9
    );

    // Reply Button
    const replyButtonWidth = i18n("wizard.previews.reply_button").length * 11;

    ctx.beginPath();
    ctx.rect(
      shareButtonWidth + margin + 10,
      line + lineHeight,
      replyButtonWidth,
      height * 0.1
    );
    ctx.fillStyle = colors.tertiary;
    ctx.fill();
    ctx.fillStyle = colors.secondary;
    ctx.font = `${bodyFontSize}em '${font}'`;
    ctx.fillText(
      i18n("wizard.previews.reply_button"),
      shareButtonWidth + margin + 20,
      line + lineHeight * 1.9
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
