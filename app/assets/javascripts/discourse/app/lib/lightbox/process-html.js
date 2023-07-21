import { SELECTORS } from "./constants";
import { escapeExpression } from "discourse/lib/utilities";
import { htmlSafe } from "@ember/template";

export async function processHTML({ container, selector, clickTarget }) {
  selector ??= SELECTORS.DEFAULT_ITEM_SELECTOR;

  const items = [...container.querySelectorAll(selector)];

  let _startingIndex = items.findIndex((item) => item === clickTarget);

  if (_startingIndex === -1) {
    _startingIndex = 0;
  }

  const backgroundImageRegex = /url\((['"])?(.*?)\1\)/gi;

  const _processedItems = items.map((item, index) => {
    try {
      const innerImage = item.querySelector("img") || {};

      const _backgroundImage =
        item.style?.backgroundImage ||
        item.parentElement?.style?.backgroundImage ||
        null;

      const _fullsizeURL = item.href || item.src || innerImage.src || null;

      const _smallURL =
        innerImage.currentSrc ||
        item.src ||
        innerImage.src ||
        _backgroundImage?.replace(backgroundImageRegex, "$2") ||
        null;

      const _downloadURL =
        item.dataset?.downloadHref ||
        item.href ||
        item.src ||
        innerImage.src ||
        null;

      const _title =
        item.title || item.alt || innerImage.title || innerImage.alt || null;

      const _aspectRatio =
        item.dataset?.aspectRatio ||
        innerImage.dataset?.aspectRatio ||
        item.style?.aspectRatio ||
        innerImage.style?.aspectRatio ||
        null;

      const _fileDetails =
        item
          .querySelector(SELECTORS.FILE_DETAILS_CONTAINER)
          ?.innerText.trim() || null;

      const _dominantColor = innerImage.dataset?.dominantColor || null;

      const _cssVars = [
        _dominantColor && `--dominant-color: #${_dominantColor};`,
        _aspectRatio && `--aspect-ratio: ${_aspectRatio};`,
        _smallURL && `--small-url: url(${encodeURI(_smallURL)});`,
      ].join("");

      return {
        fullsizeURL: encodeURI(_fullsizeURL),
        smallURL: encodeURI(_smallURL),
        downloadURL: encodeURI(_downloadURL),
        title: escapeExpression(_title),
        fileDetails: _fileDetails,
        dominantColor: _dominantColor,
        aspectRatio: _aspectRatio,
        index,
        cssVars: htmlSafe(_cssVars),
      };
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error(`Error processing lightbox item ${index}`);
      // eslint-disable-next-line no-console
      console.error(error);
    }
  });

  return {
    items: _processedItems,
    startingIndex: _startingIndex,
  };
}
