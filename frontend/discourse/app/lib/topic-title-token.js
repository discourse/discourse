export default function topicTitleToken(model, siteSettings) {
  if (!model) {
    return;
  }

  if (model.get("errorHtml")) {
    return model.get("errorTitle");
  }

  let result;

  const titleLocalized = model.get("fancy_title_localized");
  if (titleLocalized) {
    const fancyTitle = model.get("fancy_title");
    const tempDiv = document.createElement("div");
    tempDiv.innerHTML = fancyTitle;
    result = tempDiv.textContent || tempDiv.innerText || fancyTitle;
  } else {
    result = model.get("unicode_title") || model.get("title");
  }

  const cat = model.get("category");
  if (
    siteSettings.topic_page_title_includes_category &&
    cat &&
    !(
      cat.get("isUncategorizedCategory") &&
      cat.get("name").toLowerCase() === "uncategorized"
    )
  ) {
    let catName = cat.get("name");

    const parentCategory = cat.get("parentCategory");
    if (parentCategory) {
      catName = parentCategory.get("name") + " / " + catName;
    }

    return [result, catName];
  }

  return result;
}
