# frozen_string_literal: true

RSpec.describe "When ActiveRecord is preventing writes" do
  before do
    @original_async = Scheduler::Defer.async
    Scheduler::Defer.async = true
  end

  after { Scheduler::Defer.async = @original_async }

  it "should not result in an error response when there is a theme field that needs to be baked" do
    theme_field =
      Fabricate(
        :theme_field,
        type_id: ThemeField.types[:html],
        target_id: Theme.targets[:common],
        name: "head_tag",
        value: <<~HTML,
        <script type="text/discourse-plugin" version="0.1">
          console.log(settings.uploads.imajee);
        </script>
      HTML
      )

    SiteSetting.default_theme_id = theme_field.theme_id

    ActiveRecord::Base.connected_to(role: ActiveRecord.writing_role, prevent_writes: true) do
      get "/latest"

      expect(request.env[:resolved_theme_id]).to eq(theme_field.theme_id)
      expect(response.status).to eq(200)
    end
  end
end
