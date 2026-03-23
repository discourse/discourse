import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";

export default class VariableInput extends Component {
  @tracked isDragOver = false;
  editorElement = null;

  @action
  setupEditor(element) {
    this.editorElement = element;
    this.#renderContent(this.args.value || "");
  }

  @action
  handleInput() {
    this.args.onChange?.(this.#serialize());
  }

  @action
  handleClick() {
    if (!this.editorElement.childNodes.length) {
      this.editorElement.appendChild(document.createTextNode(""));
    }

    const selection = window.getSelection();
    if (
      !selection.rangeCount ||
      !this.editorElement.contains(selection.anchorNode)
    ) {
      const range = document.createRange();
      const lastChild = this.editorElement.lastChild;
      if (lastChild?.nodeType === Node.TEXT_NODE) {
        range.setStart(lastChild, lastChild.textContent.length);
      } else {
        range.setStart(
          this.editorElement,
          this.editorElement.childNodes.length
        );
      }
      range.collapse(true);
      selection.removeAllRanges();
      selection.addRange(range);
    }
  }

  @action
  handleDragOver(event) {
    if (event.dataTransfer.types.includes("application/x-workflow-variable")) {
      event.preventDefault();
      event.dataTransfer.dropEffect = "copy";
      this.isDragOver = true;
    }
  }

  @action
  handleDragLeave() {
    this.isDragOver = false;
  }

  @action
  handleDrop(event) {
    const data = event.dataTransfer.getData("application/x-workflow-variable");
    if (!data) {
      return;
    }

    event.preventDefault();
    this.isDragOver = false;

    let variable;
    try {
      variable = JSON.parse(data);
    } catch {
      return;
    }
    const variableId = variable.id.startsWith("$")
      ? variable.id
      : `$json.${variable.id}`;
    const pill = this.#createPill(variableId);

    const trailing = document.createTextNode(" ");

    const selection = window.getSelection();
    if (
      selection.rangeCount &&
      this.editorElement.contains(selection.anchorNode)
    ) {
      const range = selection.getRangeAt(0);
      range.deleteContents();
      range.insertNode(trailing);
      range.insertNode(pill);
    } else {
      this.editorElement.appendChild(pill);
      this.editorElement.appendChild(trailing);
    }

    this.#focusAtEnd();
    this.args.onChange?.(this.#serialize());
  }

  @action
  handleKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      event.stopPropagation();
      document.execCommand("insertLineBreak");
      return;
    }
  }

  @action
  handlePaste(event) {
    event.preventDefault();
    const text = event.clipboardData.getData("text/plain");
    document.execCommand("insertText", false, text);
  }

  #focusAtEnd() {
    this.editorElement.focus();
    const selection = window.getSelection();
    const range = document.createRange();
    range.selectNodeContents(this.editorElement);
    range.collapse(false);
    selection.removeAllRanges();
    selection.addRange(range);
  }

  #createPill(variableId) {
    const pill = document.createElement("span");
    pill.className = "workflows-variable-pill";
    pill.dataset.variableId = variableId;
    pill.textContent = variableId;
    return pill;
  }

  #renderContent(value) {
    if (!this.editorElement) {
      return;
    }

    this.editorElement.innerHTML = "";
    const regex = /\{\{\s*([^}]+?)\s*\}\}|\n/g;
    let lastIndex = 0;
    let match;

    while ((match = regex.exec(value)) !== null) {
      if (match.index > lastIndex) {
        this.editorElement.appendChild(
          document.createTextNode(value.slice(lastIndex, match.index))
        );
      }

      if (match[0] === "\n") {
        this.editorElement.appendChild(document.createElement("br"));
      } else {
        this.editorElement.appendChild(this.#createPill(match[1]));
      }

      lastIndex = regex.lastIndex;
    }

    if (lastIndex < value.length) {
      this.editorElement.appendChild(
        document.createTextNode(value.slice(lastIndex))
      );
    }
  }

  #serialize() {
    return this.#serializeNodes(this.editorElement.childNodes);
  }

  #serializeNodes(nodes) {
    let result = "";
    for (const node of nodes) {
      if (node.nodeType === Node.TEXT_NODE) {
        result += node.textContent;
      } else if (node.nodeName === "BR") {
        result += "\n";
      } else if (node.classList?.contains("workflows-variable-pill")) {
        result += `{{ ${node.textContent.trim()} }}`;
      } else if (node.childNodes.length) {
        result += "\n" + this.#serializeNodes(node.childNodes);
      }
    }
    return result;
  }

  <template>
    <div
      class="workflows-variable-input {{if this.isDragOver '--drag-over'}}"
      contenteditable="true"
      role="textbox"
      {{didInsert this.setupEditor}}
      {{on "click" this.handleClick}}
      {{on "keydown" this.handleKeydown}}
      {{on "input" this.handleInput}}
      {{on "dragover" this.handleDragOver}}
      {{on "dragleave" this.handleDragLeave}}
      {{on "drop" this.handleDrop}}
      {{on "paste" this.handlePaste}}
    ></div>
  </template>
}
