# app/services/dlocal_service.rb
require 'openssl'
require 'net/http'
require 'json'

class DlocalService
  DLOCAL_SANDBOX_URL = 'https://sandbox.dlocal.com'.freeze
  DLOCAL_PRODUCTION_URL = 'https://api.dlocal.com'.freeze

  def initialize(env = 'sandbox')
    @base_url = env == 'production' ? DLOCAL_PRODUCTION_URL : DLOCAL_SANDBOX_URL
    @secret_key = ENV["DLOCAL_SECRET_KEY"]
    @x_login = ENV["DLOCAL_X_LOGIN"]
    @x_trans_key = ENV["DLOCaL_X_TRANS_KEY"]
  end

  def create_payment(payment_params)
    x_date = Time.now.utc.iso8601
    request_body = payment_params.to_json

    signature = generate_signature(@x_login, x_date, request_body)
    headers = build_headers(x_date, signature)

    uri = URI("#{@base_url}/secure_payments")
    response = send_request(uri, headers, request_body)

    handle_response(response)
  end

  private

  def generate_signature(x_login, x_date, request_body)
    data = "#{x_login}#{x_date}#{request_body}"
    OpenSSL::HMAC.hexdigest('sha256', @secret_key, data)
  end

  def build_headers(x_date, signature)
    {
      'X-Date' => x_date,
      'X-Login' => @x_login,
      'X-Trans-Key' => @x_trans_key,
      'Content-Type' => 'application/json',
      'Authorization' => "V2-HMAC-SHA256, Signature: #{signature}"
    }
  end

  def send_request(uri, headers, body)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.path, headers)
    request.body = body

    http.request(request)
  end

  def handle_response(response)
    case response.code.to_i
    when 200..299
      JSON.parse(response.body)
    else
      { error: "dLocal API Error: #{response.code} - #{response.body}" }
    end
  end
end