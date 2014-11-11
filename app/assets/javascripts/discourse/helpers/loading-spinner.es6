var spinnerHTML = "<div class='spinner'></div>";

Handlebars.registerHelper('loading-spinner', function() {
    return new Handlebars.SafeString(spinnerHTML);
});

export { spinnerHTML };
