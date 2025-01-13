import { i18n } from "discourse-i18n";
import { darkLightDiff } from "../../../lib/preview";
import PreviewBaseComponent from "./-preview-base";

export default class HomepagePreview extends PreviewBaseComponent {
  width = 628;
  height = 322;
  logo = null;
  avatar = null;

  didUpdateAttrs() {
    super.didUpdateAttrs(...arguments);

    this.triggerRepaint();
  }

  images() {
    return {
      logo: this.wizard.logoUrl,
      avatar: "/images/wizard/trout.png",
    };
  }

  paint({ ctx, colors, font, width, height }) {
    this.drawFullHeader(colors, font, this.logo);

    const homepageStyle = this.getHomepageStyle();

    if (homepageStyle === "latest" || homepageStyle === "hot") {
      this.drawPills(colors, font, height * 0.15, { homepageStyle });
      this.renderNonCategoryHomepage(
        ctx,
        colors,
        font,
        width,
        height,
        homepageStyle
      );
    } else if (
      ["categories_only", "categories_with_featured_topics"].includes(
        homepageStyle
      )
    ) {
      this.drawPills(colors, font, height * 0.15, { homepageStyle });
      this.renderCategories(ctx, colors, font, width, height);
    } else if (
      ["categories_boxes", "categories_boxes_with_topics"].includes(
        homepageStyle
      )
    ) {
      this.drawPills(colors, font, height * 0.15, { homepageStyle });
      const topics = homepageStyle === "categories_boxes_with_topics";
      this.renderCategoriesBoxes(ctx, colors, font, width, height, { topics });
    } else {
      this.drawPills(colors, font, height * 0.15, { homepageStyle });
      this.renderCategoriesWithTopics(ctx, colors, font, width, height);
    }
  }

  renderCategoriesBoxes(ctx, colors, font, width, height, opts) {
    opts = opts || {};

    const borderColor = darkLightDiff(
      colors.primary,
      colors.secondary,
      90,
      -75
    );
    const textColor = darkLightDiff(colors.primary, colors.secondary, 50, 50);
    const margin = height * 0.03;
    const bodyFontSize = height / 440.0;
    const boxHeight = height * 0.7 - margin * 2;
    const descriptions = this.getDescriptions();
    const boxesSpacing = 15;
    const boxWidth = (width - margin * 2 - boxesSpacing * 2) / 3;

    this.categories().forEach((category, index) => {
      const boxStartX = margin + index * boxWidth + index * boxesSpacing;
      const boxStartY = height * 0.33;

      this.drawSquare(
        ctx,
        { x: boxStartX, y: boxStartY },
        { x: boxStartX + boxWidth, y: boxStartY + boxHeight },
        [
          { color: borderColor },
          { color: borderColor },
          { color: borderColor },
          { color: category.color, width: 5 },
        ]
      );

      ctx.font = `700 ${bodyFontSize * 1.3}em '${font}'`;
      ctx.fillStyle = colors.primary;
      ctx.textAlign = "center";
      ctx.fillText(category.name, boxStartX + boxWidth / 2, boxStartY + 25);
      ctx.textAlign = "left";

      if (opts.topics) {
        let startY = boxStartY + 60;
        this.getTitles().forEach((title) => {
          ctx.font = `${bodyFontSize * 1}em '${font}'`;
          ctx.fillStyle = colors.tertiary;
          startY +=
            this.fillTextMultiLine(
              ctx,
              title.split("\n").join(" "),
              boxStartX + 10,
              startY,
              13,
              boxWidth * 0.95
            ) + 8;
        });
      } else {
        ctx.font = `${bodyFontSize * 1}em '${font}'`;
        ctx.fillStyle = textColor;
        ctx.textAlign = "center";
        this.fillTextMultiLine(
          ctx,
          descriptions[index],
          boxStartX + boxWidth / 2,
          boxStartY + 60,
          13,
          boxWidth * 0.8
        );
        ctx.textAlign = "left";
      }
    });
  }

  renderCategories(ctx, colors, font, width, height) {
    const textColor = darkLightDiff(colors.primary, colors.secondary, 50, 50);
    const margin = height * 0.03;
    const bodyFontSize = height / 440.0;
    const titles = this.getTitles();
    let categoryHeight = height / 6;

    const drawLine = (x, y) => {
      ctx.beginPath();
      ctx.strokeStyle = darkLightDiff(
        colors.primary,
        colors.secondary,
        90,
        -75
      );
      ctx.moveTo(margin + x, y);
      ctx.lineTo(width - margin, y);
      ctx.stroke();
    };

    const cols = [0.025, 0.45, 0.53, 0.58, 0.94, 0.96].map((c) => c * width);

    const headingY = height * 0.33;
    ctx.font = `${bodyFontSize * 0.9}em '${font}'`;
    ctx.fillStyle = textColor;
    ctx.fillText("Category", cols[0], headingY);

    const homepageStyle = this.getHomepageStyle();

    if (homepageStyle === "categories_only") {
      ctx.fillText("Topics", cols[4], headingY);
    } else {
      ctx.fillText("Topics", cols[1], headingY);
      ctx.fillText("Latest", cols[2], headingY);
      categoryHeight = height / 5;
    }

    let y = headingY + bodyFontSize * 12;
    ctx.lineWidth = 2;
    drawLine(0, y);
    drawLine(width / 2, y);

    // Categories
    this.categories().forEach((category, idx) => {
      const textPos = y + categoryHeight * 0.35;
      ctx.font = `700 ${bodyFontSize * 1.1}em '${font}'`;
      ctx.fillStyle = colors.primary;
      ctx.fillText(category.name, cols[0], textPos);

      ctx.font = `${bodyFontSize * 0.8}em '${font}'`;
      ctx.fillStyle = textColor;
      ctx.fillText(
        titles[idx],
        cols[0] - margin * 0.25,
        textPos + categoryHeight * 0.36
      );

      ctx.beginPath();
      ctx.moveTo(margin, y);
      ctx.strokeStyle = category.color;
      ctx.lineWidth = 3.5;
      ctx.lineTo(margin, y + categoryHeight);
      ctx.stroke();

      if (homepageStyle === "categories_with_featured_topics") {
        ctx.font = `${bodyFontSize}em '${font}'`;
        ctx.fillText(
          Math.floor(Math.random() * 90) + 10,
          cols[1] + 15,
          textPos
        );
      } else {
        ctx.font = `${bodyFontSize}em '${font}'`;
        ctx.fillText(Math.floor(Math.random() * 90) + 10, cols[5], textPos);
      }

      y += categoryHeight;
      ctx.lineWidth = 1;
      drawLine(0, y);
    });

    // Featured Topics
    if (homepageStyle === "categories_with_featured_topics") {
      const topicHeight = height / 15;

      y = headingY + bodyFontSize * 22;
      ctx.lineWidth = 1;
      ctx.fillStyle = colors.tertiary;

      titles.forEach((title) => {
        ctx.font = `${bodyFontSize}em '${font}'`;
        const textPos = y + topicHeight * 0.35;
        ctx.fillStyle = colors.tertiary;
        ctx.fillText(`${title}`, cols[2], textPos);
        y += topicHeight;
      });
    }
  }

  renderCategoriesWithTopics(ctx, colors, font, width, height) {
    const textColor = darkLightDiff(colors.primary, colors.secondary, 50, 50);
    const margin = height * 0.03;
    const bodyFontSize = height / 440.0;

    const drawLine = (x, y) => {
      ctx.beginPath();
      ctx.strokeStyle = darkLightDiff(
        colors.primary,
        colors.secondary,
        90,
        -75
      );
      ctx.moveTo(margin + x, y);
      ctx.lineTo(margin + x + (width * 0.9) / 2, y);
      ctx.stroke();
    };

    const cols = [0.025, 0.42, 0.53, 0.58, 0.94].map((c) => c * width);

    const headingY = height * 0.33;
    ctx.font = `${bodyFontSize * 0.9}em '${font}'`;
    ctx.fillStyle = textColor;
    ctx.fillText("Category", cols[0], headingY);
    ctx.fillText("Topics", cols[1], headingY);
    if (this.getHomepageStyle() === "categories_and_latest_topics") {
      ctx.fillText("Latest", cols[2], headingY);
    } else {
      ctx.fillText("Top", cols[2], headingY);
    }

    let y = headingY + bodyFontSize * 12;
    ctx.lineWidth = 2;
    drawLine(0, y);
    drawLine(width / 2, y);

    const categoryHeight = height / 6;
    const titles = this.getTitles();

    // Categories
    this.categories().forEach((category, idx) => {
      const textPos = y + categoryHeight * 0.35;
      ctx.font = `700 ${bodyFontSize * 1.1}em '${font}'`;
      ctx.fillStyle = colors.primary;
      ctx.fillText(category.name, cols[0], textPos);

      ctx.font = `${bodyFontSize * 0.8}em '${font}'`;
      ctx.fillStyle = textColor;
      ctx.fillText(
        titles[idx],
        cols[0] - margin * 0.25,
        textPos + categoryHeight * 0.36
      );

      ctx.beginPath();
      ctx.moveTo(margin, y);
      ctx.strokeStyle = category.color;
      ctx.lineWidth = 3.5;
      ctx.lineTo(margin, y + categoryHeight);
      ctx.stroke();

      ctx.font = `${bodyFontSize}em '${font}'`;
      ctx.fillText(Math.floor(Math.random() * 90) + 10, cols[1] + 15, textPos);

      y += categoryHeight;
      ctx.lineWidth = 1;
      drawLine(0, y);
    });

    // Latest/Top Topics
    const topicHeight = height / 8;
    const avatarSize = topicHeight * 0.7;
    y = headingY + bodyFontSize * 12;
    ctx.lineWidth = 1;
    ctx.fillStyle = textColor;

    titles.forEach((title) => {
      const category = this.categories()[0];
      ctx.font = `${bodyFontSize}em '${font}'`;
      const textPos = y + topicHeight * 0.45;
      ctx.fillStyle = colors.primary;
      this.scaleImage(
        this.avatar,
        cols[2],
        y + margin * 0.6,
        avatarSize,
        avatarSize
      );
      ctx.fillText(title, cols[3], textPos);

      ctx.font = `700 ${bodyFontSize}em '${font}'`;
      ctx.fillText(Math.floor(Math.random() * 90) + 10, cols[4], textPos);
      ctx.font = `${bodyFontSize}em '${font}'`;
      ctx.fillText(`1h`, cols[4], textPos + topicHeight * 0.4);

      ctx.beginPath();
      ctx.fillStyle = category.color;
      const badgeSize = topicHeight * 0.1;
      ctx.font = `700 ${bodyFontSize * 0.5}em '${font}'`;
      ctx.rect(
        cols[3] + margin * 0.25,
        y + topicHeight * 0.65,
        badgeSize,
        badgeSize
      );
      ctx.fill();

      ctx.fillStyle = colors.primary;
      ctx.fillText(
        category.name,
        cols[3] + badgeSize * 2,
        y + topicHeight * 0.76
      );
      y += topicHeight;

      drawLine(width / 2, y);
    });
  }

  getHomepageStyle() {
    return this.step.valueFor("homepage_style");
  }

  getTitles() {
    return [
      i18n("wizard.homepage_preview.topic_titles.what_books"),
      i18n("wizard.homepage_preview.topic_titles.what_movies"),
      i18n("wizard.homepage_preview.topic_titles.random_fact"),
      i18n("wizard.homepage_preview.topic_titles.tv_show"),
    ];
  }

  getHotTitles() {
    return [
      i18n("wizard.homepage_preview.topic_titles.what_hobbies"),
      i18n("wizard.homepage_preview.topic_titles.what_music"),
      i18n("wizard.homepage_preview.topic_titles.funniest_thing"),
      i18n("wizard.homepage_preview.topic_titles.share_art"),
    ];
  }

  getDescriptions() {
    return [
      i18n("wizard.homepage_preview.category_descriptions.icebreakers"),
      i18n("wizard.homepage_preview.category_descriptions.news"),
      i18n("wizard.homepage_preview.category_descriptions.site_feedback"),
    ];
  }

  renderNonCategoryHomepage(ctx, colors, font, width, height, homepageStyle) {
    const rowHeight = height / 6.6;
    // accounts for hard-set color variables in solarized themes
    const textColor =
      colors.primary_medium ||
      darkLightDiff(colors.primary, colors.secondary, 50, 50);
    const bodyFontSize = height / 440.0;

    ctx.font = `${bodyFontSize}em '${font}'`;

    const margin = height * 0.03;

    const drawLine = (y) => {
      ctx.beginPath();
      // accounts for hard-set color variables in solarized themes
      ctx.strokeStyle =
        colors.primary_low ||
        darkLightDiff(colors.primary, colors.secondary, 90, -75);
      ctx.moveTo(margin, y);
      ctx.lineTo(width - margin, y);
      ctx.stroke();
    };

    const cols = [0.02, 0.66, 0.75, 0.83, 0.9].map((c) => c * width);

    // Headings
    const headingY = height * 0.33;

    ctx.fillStyle = textColor;
    ctx.font = `${bodyFontSize * 0.9}em '${font}'`;
    ctx.fillText(
      i18n("wizard.homepage_preview.table_headers.topic"),
      cols[0],
      headingY
    );
    ctx.fillText(
      i18n("wizard.homepage_preview.table_headers.replies"),
      cols[2],
      headingY
    );
    ctx.fillText(
      i18n("wizard.homepage_preview.table_headers.views"),
      cols[3],
      headingY
    );
    ctx.fillText(
      i18n("wizard.homepage_preview.table_headers.activity"),
      cols[4],
      headingY
    );

    // Topics
    let y = headingY + rowHeight / 2.6;
    ctx.lineWidth = 2;
    drawLine(y);

    ctx.font = `${bodyFontSize}em '${font}'`;
    ctx.lineWidth = 1;

    const titles =
      homepageStyle === "hot" ? this.getHotTitles() : this.getTitles();
    titles.forEach((title) => {
      const textPos = y + rowHeight * 0.4;
      ctx.fillStyle = colors.primary;
      ctx.fillText(title, cols[0], textPos);

      // Category badge
      const category = this.categories()[0];
      ctx.beginPath();
      ctx.fillStyle = category.color;
      const badgeSize = rowHeight * 0.15;
      ctx.font = `700 ${bodyFontSize * 0.75}em '${font}'`;
      ctx.rect(cols[0] + 4, y + rowHeight * 0.6, badgeSize, badgeSize);
      ctx.fill();

      ctx.fillStyle = colors.primary;
      ctx.fillText(
        category.name,
        cols[0] + badgeSize * 2,
        y + rowHeight * 0.73
      );
      this.scaleImage(
        this.avatar,
        cols[1],
        y + rowHeight * 0.25,
        rowHeight * 0.5,
        rowHeight * 0.5
      );

      ctx.fillStyle = textColor;
      ctx.font = `${bodyFontSize}em '${font}'`;
      for (let colIndex = 2; colIndex <= 4; colIndex++) {
        // Give Hot a higher range of random values to make it look like
        // more activity is happening.
        const randomValue =
          homepageStyle === "hot"
            ? Math.floor(Math.random() * (660 - 220) + 220) + 10
            : Math.floor(Math.random() * 90) + 10;

        ctx.fillText(
          // Last column is relative activity time, others are random numbers.
          colIndex === 4 ? "1h" : randomValue,
          cols[colIndex] + margin,
          y + rowHeight * 0.6
        );
      }
      drawLine(y + rowHeight * 1);
      y += rowHeight;
    });
  }

  fillTextMultiLine(ctx, text, x, y, lineHeight, maxWidth) {
    const words = text.split(" ").filter((f) => f);
    let line = "";
    let totalHeight = 0;

    words.forEach((word) => {
      if (ctx.measureText(`${line} ${word} `).width >= maxWidth) {
        ctx.fillText(line, x, y + totalHeight);
        totalHeight += lineHeight;
        line = word.trim();
      } else {
        line = `${line} ${word}`.trim();
      }
    });

    ctx.fillText(line, x, y + totalHeight);
    totalHeight += lineHeight;

    return totalHeight;
  }

  // Edges expected in this order: NW to NE -> NE to SE -> SE to SW -> SW to NW
  drawSquare(ctx, from, to, edges = []) {
    const edgeConfiguration = (index) => {
      const edge = edges[index] || {};

      return {
        width: edge.width || 1,
        color: edge.color || "#333",
      };
    };

    [
      { from: { x: from.x, y: from.y }, to: { x: to.x, y: from.y } },
      { from: { x: to.x, y: from.y }, to: { x: to.x, y: to.y } },
      { from: { x: to.x, y: to.y }, to: { x: from.x, y: to.y } },
      { from: { x: from.x, y: to.y }, to: { x: from.x, y: from.y } },
    ].forEach((path, index) => {
      const configuration = edgeConfiguration(index);
      ctx.beginPath();
      ctx.moveTo(path.from.x, path.from.y);
      ctx.strokeStyle = configuration.color;
      ctx.lineWidth = configuration.width;
      ctx.lineTo(path.to.x, path.to.y);
      ctx.stroke();
    });
  }
}
