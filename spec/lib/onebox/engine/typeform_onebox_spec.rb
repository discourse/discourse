# frozen_string_literal: true

require "rails_helper"

describe Onebox::Engine::TypeformOnebox do
  it 'Appends the embed widget param when is missing' do
    raw_preview = Onebox.preview('https://basvanleeuwen1.typeform.com/to/NzdRpx').to_s
    query_params = get_query_params(raw_preview)

    expect_to_have_embed_widget(query_params)
  end

  it 'Uses the URL as it is when the embed widget param is present' do
    raw_preview = Onebox.preview('https://basvanleeuwen1.typeform.com/to/NzdRpx?typeform-embed=embed-widget').to_s
    query_params = get_query_params(raw_preview)

    expect_to_have_embed_widget(query_params)
  end

  it 'Does not adds an ? when it is already present' do
    raw_preview = Onebox.preview('https://basvanleeuwen1.typeform.com/to/NzdRpx?').to_s
    query_params = get_query_params(raw_preview)

    expect_to_have_embed_widget(query_params)
  end

  it 'Appends it to the end when there are other params present' do
    raw_preview = Onebox.preview('https://basvanleeuwen1.typeform.com/to/NzdRpx?param1=value1').to_s
    query_params = get_query_params(raw_preview)

    expect_to_have_embed_widget(query_params)
  end

  def expect_to_have_embed_widget(query_params)
    expected_widget_type = ['embed-widget']
    current_widget_type = query_params.fetch('typeform-embed', [])

    expect(current_widget_type).to eq expected_widget_type
  end

  def get_query_params(raw_preview)
    form_url = inspect_html_fragment(raw_preview, 'iframe', 'src')
    CGI::parse(URI::parse(form_url).query || '')
  end
end
