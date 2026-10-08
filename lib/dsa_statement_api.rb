# frozen_string_literal: true
class DsaStatementApi
  def submit(statements:)
    if SiteSetting.dsa_api_token.blank?
      statements.each do |statement|
        statement.record_failure!(code: "configuration", temporary: false)
      end
      return
    end

    remaining =
      statements.select do |statement|
        if !statement.submission_metadata_complete?
          statement.record_failure!(code: "metadata", temporary: false)
          false
        elsif statement.attempts > 1
          reconcile(statement)
        else
          true
        end
      end
    remaining.group_by(&:api_environment).each_value { |batch| submit_batch(batch) }
  end

  private

  def reconcile(statement)
    response =
      request(
        method: :get,
        path: "/statement/existing-puid/#{statement.puid}",
        environment: statement.api_environment,
      )
    if response.status == 302 && parse_response(response)["puid"] == statement.puid
      statement.record_submission!
      false
    elsif response.status == 404
      true
    else
      record_http_failure(statement: statement, response: response)
      false
    end
  rescue Faraday::Error, JSON::ParserError
    statement.record_failure!(code: "submission", temporary: true)
    false
  end

  def submit_batch(statements)
    response =
      request(
        method: :post,
        path: "/statements",
        payload: {
          statements: statements.map(&:payload),
        },
        environment: statements.first.api_environment,
      )
    body = parse_response(response)
    if response.status == 201
      received =
        Array(body["statements"])
          .select { |receipt| receipt.is_a?(Hash) }
          .index_by { |receipt| receipt["puid"] }
      statements.each do |statement|
        receipt = received[statement.puid]
        if receipt && receipt["uuid"].present?
          statement.record_submission!(uuid: receipt["uuid"])
        else
          statement.record_failure!(code: "submission", temporary: true)
        end
      end
    elsif response.status == 422
      duplicate = body["existing"]
      errors = body["errors"].is_a?(Hash) ? body["errors"] : {}
      duplicate_puids = Array(errors["existing_puids"])
      invalid_indices =
        errors.keys.filter_map do |key|
          (key[/\Astatement_(\d+)\z/, 1] || key[/\Astatements\.(\d+)\./, 1])&.to_i
        end
      statements.each_with_index do |statement, index|
        if duplicate.is_a?(Hash) && duplicate["puid"] == statement.puid
          statement.record_submission!(uuid: duplicate["uuid"])
        elsif duplicate_puids.include?(statement.puid)
          reconcile(statement)
        elsif duplicate_puids.present? ||
              invalid_indices.present? && invalid_indices.exclude?(index)
          statement.record_failure!(code: "submission", temporary: true, retry_after_seconds: 60)
        else
          statement.record_failure!(code: "validation", temporary: false)
        end
      end
    else
      statements.each { |statement| record_http_failure(statement: statement, response: response) }
    end
  rescue Faraday::Error, JSON::ParserError
    statements.each { |statement| statement.record_failure!(code: "submission", temporary: true) }
  end

  def record_http_failure(statement:, response:)
    if response.status.in?([401, 403])
      statement.record_failure!(code: "authentication", temporary: false)
    else
      statement.record_failure!(
        code: "submission",
        temporary: response.status == 429 || response.status >= 500,
        retry_after_seconds: retry_after_seconds(response),
      )
    end
  end

  def parse_response(response)
    body = JSON.parse(response.body)
    body.is_a?(Hash) ? body : {}
  rescue JSON::ParserError
    {}
  end

  def retry_after_seconds(response)
    value = response.headers["retry-after"]
    return if value.blank?
    return value.to_i if value.match?(/\A\d+\z/)

    (Time.httpdate(value) - Time.now).ceil
  rescue ArgumentError
    nil
  end

  def request(method:, path:, environment:, payload: nil)
    host =
      environment == "production" ? "transparency.dsa.ec.europa.eu" : "sandbox.sor.dsa.ec.europa.eu"
    connection = Faraday.new { |builder| builder.adapter FinalDestination::FaradayAdapter }
    connection.run_request(
      method,
      "https://#{host}/api/v1#{path}",
      payload&.to_json,
      {
        "Authorization" => "Bearer #{SiteSetting.dsa_api_token}",
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "User-Agent" => Discourse.user_agent,
      },
    ) do |request|
      request.options.timeout = 10
      request.options.open_timeout = 5
    end
  end
end
