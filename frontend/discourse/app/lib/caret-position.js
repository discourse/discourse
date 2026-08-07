import domUtils from "discourse/lib/dom-utils";

function getCaret(el) {
  if (el.selectionStart) {
    return el.selectionStart;
  }
  return 0;
}

// Retrieve the pixel coordinates of the caret within a textarea, relative to
// the textarea itself. It works by rendering an off-screen clone of the
// textarea's content and measuring where the caret would land.
export function caretCoordinates(element, options) {
  const styles = getComputedStyle(element);
  const important = (prop) => styles.getPropertyValue(prop);
  const isRTL = document.documentElement.classList.contains("rtl");

  const clone = document.createElement("div");
  const p = document.createElement("p");
  clone.appendChild(p);
  document.body.appendChild(clone);

  try {
    Object.assign(clone.style, {
      boxSizing: "content-box",
      border: "1px solid black",
      padding: important("padding"),
      resize: important("resize"),
      maxHeight: important("height"),
      overflowY: "auto",
      wordWrap: "break-word",
      position: "absolute",
      left: isRTL ? "auto" : "-7000px",
      right: isRTL ? "-7000px" : "auto",
      width: important("width"),
      height: important("height"),
    });

    Object.assign(p.style, {
      margin: 0,
      padding: 0,
      wordWrap: "break-word",
      letterSpacing: important("letter-spacing"),
      fontFamily: important("font-family"),
      fontSize: important("font-size"),
      lineHeight: important("line-height"),
    });

    const pos =
      options && (options.pos || options.pos === 0)
        ? options.pos
        : getCaret(element);

    let val = element.value.replace("\r", "");
    if (options && options.key) {
      val = val.substring(0, pos) + options.key + val.substring(pos);
    }
    const before = pos - 1;
    const after = pos;

    // if before and after are \n insert a space
    const insertSpaceAfterBefore = val[before] === "\n" && val[after] === "\n";

    const guard = function (v) {
      let buf = v.replace(/</g, "&lt;");
      buf = buf.replace(/>/g, "&gt;");
      buf = buf.replace(/[ ]/g, "&#x200b;&nbsp;&#x200b;");
      return buf.replace(/\n/g, "<br />");
    };

    const makeCursor = function (index, klass, color) {
      const l = val.substring(index, index + 1);
      if (l === "\n") {
        return "<br>";
      }
      return (
        "<span class='" +
        klass +
        "' style='background-color:" +
        color +
        "; margin:0; padding: 0'>" +
        guard(l) +
        "</span>"
      );
    };

    let html = "";

    if (before >= 0) {
      html +=
        guard(val.substring(0, pos - 1)) +
        makeCursor(before, "before", "#d0ffff");
      if (insertSpaceAfterBefore) {
        html += makeCursor(0, "post-before", "#d0ffff");
      }
    }

    if (after >= 0) {
      html += makeCursor(after, "after", "#ffd0ff");
      if (after - 1 < val.length) {
        html += guard(val.substring(after + 1));
      }
    }

    p.innerHTML = html;
    clone.scrollTop = element.scrollTop;

    const letter = p.querySelector("span");
    const letterOffset = domUtils.offset(letter);
    let left = letterOffset.left;
    if (letter.classList.contains("before")) {
      left += letter.offsetWidth;
    }

    const pOffset = domUtils.offset(p);
    return {
      left: left - pOffset.left,
      top: letterOffset.top - pOffset.top - clone.scrollTop,
    };
  } finally {
    clone.remove();
  }
}
