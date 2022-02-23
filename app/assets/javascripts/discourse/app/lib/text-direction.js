const ltrChars =
  "A-Za-z\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u02B8\u0300-\u0590\u0800-\u1FFF\u2C00-\uFB1C\uFDFE-\uFE6F\uFEFD-\uFFFF";
const rtlChars = "\u0591-\u07FF\uFB1D-\uFDFD\uFE70-\uFEFC";
const rtlDirCheck = new RegExp("^[^" + ltrChars + "]*[" + rtlChars + "]");
const ltrDirCheck = new RegExp("^[^" + rtlChars + "]*[" + ltrChars + "]");
let _siteDir;

export function isRTL(text) {
  return rtlDirCheck.test(text);
}

export function isLTR(text) {
  return ltrDirCheck.test(text);
}

export function setTextDirections(elem) {
  for (let e of elem.children) {
    if (e.textContent) {
      if (e.tagName === "ASIDE" && e.classList.contains("quote")) {
        setTextDirectionsForQuote(e);
      } else {
        e.setAttribute("dir", isRTL(e.textContent) ? "rtl" : "ltr");
      }
    }
  }
}

export function siteDir() {
  if (!_siteDir) {
    _siteDir = document.documentElement.classList.contains("rtl")
      ? "rtl"
      : "ltr";
  }
  return _siteDir;
}

export function isDocumentRTL() {
  return siteDir() === "rtl";
}

function setTextDirectionsForQuote(quoteElem) {
  for (let titleElem of quoteElem.querySelectorAll(".title")) {
    titleElem.setAttribute("dir", siteDir());
  }
  for (let quoteParagraphElem of quoteElem.querySelectorAll("blockquote > p")) {
    quoteParagraphElem.setAttribute(
      "dir",
      isRTL(quoteParagraphElem.textContent) ? "rtl" : "ltr"
    );
  }
}
