require 'spec_helper'
require 'email/message_builder'

describe Email::MessageBuilder do

  let(:to_address) { "jake@adventuretime.ooo" }
  let(:subject) { "Tree Trunks has made some apple pie!" }
  let(:body) { "oh my glob Jake, Tree Trunks just made the tastiest apple pie ever!"}
  let(:builder) { Email::MessageBuilder.new(to_address, subject: subject, body: body) }
  let(:build_args) { builder.build_args }

  it "has the correct to address" do
    expect(build_args[:to]).to eq(to_address)
  end

  it "has the subject" do
    expect(builder.subject).to eq(subject)
  end

  it "has the body" do
    expect(builder.body).to eq(body)
  end

  it "has a utf-8 charset" do
    expect(builder.build_args[:charset]).to eq("UTF-8")
  end

  context "unsubscribe link" do

    context "with add_unsubscribe_link false" do
      it "has no unsubscribe header by default" do
        expect(builder.header_args['List-Unsubscribe']).to be_blank
      end

      it "doesn't have the user preferences url in the body" do
        expect(builder.body).not_to match(builder.template_args[:user_preferences_url])
      end

    end

    context "with add_unsubscribe_link true" do

      let(:message_with_unsubscribe) { Email::MessageBuilder.new(to_address,
                                                                body: 'hello world',
                                                                add_unsubscribe_link: true) }

      it "has an List-Unsubscribe header" do
        expect(message_with_unsubscribe.header_args['List-Unsubscribe']).to be_present
      end

      it "has the user preferences url in the body" do
        expect(message_with_unsubscribe.body).to match(builder.template_args[:user_preferences_url])
      end

    end

  end

  context "template_args" do
    let(:template_args) { builder.template_args }

    it "has the site name" do
      expect(template_args[:site_name]).to eq(SiteSetting.title)
    end

    it "has the base url" do
      expect(template_args[:base_url]).to eq(Discourse.base_url)
    end

    it "has the user_preferences_url" do
      expect(template_args[:user_preferences_url]).to eq("#{Discourse.base_url}/user_preferences")
    end
  end

  context "subject_template" do

    let(:templated_builder) { Email::MessageBuilder.new(to_address, template: 'mystery') }
    let(:rendered_template) { "rendered template" }

    it "has the body rendered from a template" do
      I18n.expects(:t).with("mystery.text_body_template", templated_builder.template_args).returns(rendered_template)
      expect(templated_builder.body).to eq(rendered_template)
    end

    it "has the subject rendered from a template" do
      I18n.expects(:t).with("mystery.subject_template", templated_builder.template_args).returns(rendered_template)
      expect(templated_builder.subject).to eq(rendered_template)
    end

  end

  context "from field" do

    it "has the default from" do
      expect(build_args[:from]).to eq(SiteSetting.notification_email)
    end

    let(:finn_email) { 'finn@adventuretime.ooo' }
    let(:custom_from) { Email::MessageBuilder.new(to_address, from: finn_email).build_args }

    it "allows us to override from" do
      expect(custom_from[:from]).to eq(finn_email)
    end

    let(:aliased_from) { Email::MessageBuilder.new(to_address, from_alias: "Finn the Dog") }

    it "allows us to alias the from address" do
      expect(aliased_from.build_args[:from]).to eq("Finn the Dog <#{SiteSetting.notification_email}>")
    end

    let(:custom_aliased_from) { Email::MessageBuilder.new(to_address,
                                                          from_alias: "Finn the Dog",
                                                          from: finn_email) }

    it "allows us to alias a custom from address" do
      expect(custom_aliased_from.build_args[:from]).to eq("Finn the Dog <#{finn_email}>")
    end

  end

end
