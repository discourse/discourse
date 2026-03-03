import "./styles.css";

let dialogContent;

function setupErrorDialog() {
  const dialog = document.createElement("dialog");
  dialog.id = "discourse-error-dialog";

  const heading = document.createElement("div");
  const title = document.createElement("h1");
  title.innerText = "Plugin Error";
  heading.append(title);

  const tomster = document.createElement("img");
  tomster.src = "images/fishy-tomster.webp";
  heading.append(tomster);

  dialog.append(heading);

  dialogContent = document.createElement("ul");
  dialog.append(dialogContent);

  document.body.append(dialog);
  dialog.showModal();
}

export function addError(error, pluginName, path) {
  if (!dialogContent) {
    setupErrorDialog();
  }

  const errorElement = document.createElement("li");
  errorElement.innerText += `❌ Failed to load plugin ${pluginName} from ${path}\n${String(error)}`;
  dialogContent.append(errorElement);
}
