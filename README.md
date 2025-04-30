
```markdown
# 💳 DLocal Payment Integration – Ruby on Rails

This guide provides a complete walkthrough for integrating the [DLocal payment gateway](https://dlocal.com) into a Ruby on Rails application. It includes how to send a payment request, handle the response, and persist data using the `Payment` model.

---

## 📁 File Structure

```
app/
├── controllers/
│   └── api/v1/payments_controller.rb
├── services/
│   └── dlocal_service.rb
├── models/
│   └── payment.rb
```

---

## ⚙️ Environment Configuration

Add the following environment variables to your `.env` file or credentials store:

```env
DLOCAL_SECRET_KEY=your_secret_key
DLOCAL_X_LOGIN=your_x_login
DLOCaL_X_TRANS_KEY=your_x_trans_key
DLOCAL_MERCHANT_ID=your_merchant_id
DLOCAL_API_URL=https://sandbox.dlocal.com
DLOCAL_API_KEY=your_api_key
```

> ✅ Use the sandbox URL for testing. Update to `https://api.dlocal.com` in production.

---

## 🧾 Model Definition

**`app/models/payment.rb`**

```ruby
# == Schema Information
#
# Table name: payments
#
#  id               :integer
#  booking_id       :integer
#  payment_method   :string
#  amount           :decimal
#  currency         :string
#  transaction_id   :string
#  status           :string
#  paid_at          :datetime
#  created_at       :datetime
#  updated_at       :datetime
#  user_id          :integer
#  refund_amount    :decimal
#  refund_reason    :text
#  payment_gateway  :string
#  payment_id       :string
#  card_type        :string
#  card_last4       :string
#  response_data    :jsonb
#

class Payment < ApplicationRecord
  # Relations
  belongs_to :booking
  belongs_to :user

  # Enums
  enum status: { pending: "pending", completed: "completed", failed: "failed", refunded: "refunded" }

  # Validations
  validates :amount, :currency, presence: true
end
```

---

## 📤 Payment Request

**Endpoint:**  
`POST /api/v1/payments`

### Request Payload

```json
{
  "payment": {
    "booking_id": "123456",
    "amount": "100.00",
    "currency": "USD",
    "country": "US",
    "payment_method_id": "CARD",
    "order_id": "ORD123456",
    "description": "Payment for Order #ORD123456",
    "payment_method_flow": "DIRECT",
    "payer": {
      "name": "John Doe",
      "email": "john@example.com",
      "document": "1234567890",
      "phone": "+1234567890",
      "address": {
        "country": "US",
        "state": "CA",
        "city": "Los Angeles",
        "zip_code": "90001",
        "street": "Main Street",
        "number": "123"
      }
    },
    "card": {
      "holder_name": "John Doe",
      "number": "4111111111111111",
      "cvv": "123",
      "expiration_month": "12",
      "expiration_year": "2025"
    }
  }
}
```

---

## ✅ Success Response

```json
{
  "message": "Payment completed successfully!",
  "data": {
    "booking_id": "123456",
    "payment_id": "dlocal_txn_abc123"
  },
  "code": 200
}
```

## ❌ Error Response

```json
{
  "error": "Missing or invalid parameters",
  "code": 400
}
```

---

## 🧠 DLocal Service Implementation

**`app/services/dlocal_service.rb`**

```ruby
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
```

---

## 🎮 Controller Overview

**`app/controllers/api/v1/payments_controller.rb`**

```ruby
class Api::V1::PaymentsController < Api::V1::BaseApiController
  def create
    return render_error("Missing or invalid parameters") unless valid_payment_params?

    dlocal_response = DlocalService.new.create_payment(payment_params)

    unless dlocal_response["status"] == "PAID"
      return render_error(dlocal_response[:error], 422)
    end

    payment = build_payment_from_response(dlocal_response)

    if payment.save
      render json: {
        message: "Payment completed successfully!",
        data: {
          booking_id: payment.booking_id,
          payment_id: payment.id
        },
        code: 200
      }
    else
      render_error(payment.errors.full_messages.to_sentence, 422)
    end
  end

  def webhook
    # TODO: Add signature verification for webhook security
    head :ok
  end

  private

  def payment_params
    params.require(:payment).permit(
      :amount, :currency, :country, :payment_method_id, :order_id, :description, :payment_method_flow,
      payer: [:name, :email, :document, :phone, address: %i[country state city zip_code street number]],
      card: [:holder_name, :number, :cvv, :expiration_month, :expiration_year]
    )
  end

  def valid_payment_params?
    params[:payment] && params[:payment][:booking_id].present? && params[:payment][:amount].present? && params[:payment][:amount].to_f > 0
  end

  def build_payment_from_response(response)
    Payment.new(
      booking_id: params[:payment][:booking_id],
      amount: response["amount"],
      payment_method: response["payment_method_type"],
      currency: response["currency"],
      transaction_id: response["id"],
      status: "completed",
      paid_at: response["created_date"],
      user_id: current_user.id,
      payment_id: response["id"],
      card_type: response.dig("card", "brand"),
      card_last4: response.dig("card", "last4"),
      response_data: response
    )
  end

  def render_error(message, status = 400)
    render json: { error: message, code: status }, status: status
  end
end
```

---

## 🛡️ Security Considerations

- Use **HTTPS** in production environments.
- Validate and sanitize all incoming request data.
- Implement **signature verification** for webhook requests.
- Store sensitive credentials using Rails credentials or environment variables.

---

## ✅ Summary

With this integration, your application can securely process credit card payments using DLocal’s API, track and store transaction data, and support future webhook or refund handling extensions.

---

Need help adding webhook signature verification or writing tests for this flow?
```